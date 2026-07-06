// ================= END EXTRACTED CODE =================
//
// Hand-verifiable scenario tests: each targets one specific behaviour/bug fix
// and checks the framebuffer against an independent per-pixel painter's-algorithm
// reference. Exit 0 = all pass.

static unsigned char base[FBYTES];
static int gp(int p){ return (p&1)?(fb[p>>1]>>4)&0xF:fb[p>>1]&0xF; }
static void spx_on(unsigned char *b,int p,int v){
    if(p&1) b[p>>1]=(b[p>>1]&0x0F)|((v&0xF)<<4); else b[p>>1]=(b[p>>1]&0xF0)|(v&0xF);
}
static int fails=0, tests=0;

// One visible sprite for the reference painter.
typedef struct { unsigned char *sd; int w,h,x,y; } vis_t;

// Paint sprites in z-order (low..high) over base, per-pixel, true position.
static void ref_paint(unsigned char *out, vis_t *v, int n){
    memcpy(out, base, FBYTES);
    for(int i=0;i<n;i++){
        for(int r=0;r<v[i].h;r++) for(int c=0;c<v[i].w;c++){
            unsigned char px=v[i].sd[r*v[i].w+c]; if(px==0xFF) continue;
            int X=v[i].x+c, Y=v[i].y+r;
            if(X<0||X>=SCREENWIDTH||Y<0||Y>=SCREENHEIGHT) continue;
            spx_on(out, Y*SCREENWIDTH+X, px);
        }
    }
}
static void check(const char *name, vis_t *v, int n){
    unsigned char ref[FBYTES]; ref_paint(ref, v, n);
    tests++;
    if(memcmp(fb,ref,FBYTES)==0){ printf("  PASS  %s\n", name); return; }
    fails++;
    int fp=-1; for(int p=0;p<SCREENWIDTH*SCREENHEIGHT;p++) if(gp(p)!=((p&1)?(ref[p>>1]>>4)&0xF:ref[p>>1]&0xF)){fp=p;break;}
    printf("  FAIL  %s : first diff at (x=%d,y=%d) got=%d want=%d\n",
           name, fp%SCREENWIDTH, fp/SCREENWIDTH, gp(fp),
           (fp&1)?(ref[fp>>1]>>4)&0xF:ref[fp>>1]&0xF);
}

static unsigned char *solid(int w,int h,int col){
    unsigned char *b=malloc(w*h); for(int i=0;i<w*h;i++) b[i]=col; return b;
}
static unsigned char *distinct(int w,int h){   // every pixel opaque, varied colours
    unsigned char *b=malloc(w*h);
    for(int r=0;r<h;r++) for(int c=0;c<w;c++) b[r*w+c]=(unsigned char)(1+((r*3+c*2)%15));
    return b;
}
static void reset(void){
    for(int i=0;i<FBYTES;i++) base[i]=(unsigned char)((i*7+1)&0xFF);
    memcpy(fb,base,FBYTES);
}

// ---- edge clipping + erase round-trip (single sprite, both widths) ----
// The draw-vs-reference check uses positions where the render is pixel-exact:
// fully on-screen EVEN X, and any clipped position (which snaps to an even
// clamped X). Fully on-screen ODD X deliberately drops the rightmost column
// (documented limitation) so it is covered by test_oddx_limitation instead. The
// erase round-trip is parity-independent and is checked at EVERY X.
static void test_edge(void){
    printf("edge clip + erase round-trip (off-left / on-screen / off-right):\n");
    for(int wsel=0; wsel<2; wsel++){
        int w=wsel?32:16, h=6, maxx=SCREENWIDTH-w;
        unsigned char *sd=distinct(w,h);
        for(int x=-(w-1); x<=SCREENWIDTH-1; x++){
            int exact = (x<0) || (x>maxx) || ((x&1)==0);   // render matches true-X reference
            reset();
            loadSprite(1,w,h,sd);
            drawSprite(1,x,3,false);
            if(exact && x%3==0){ vis_t v={sd,w,h,x,3};
                char nm[48]; snprintf(nm,48,"%dw draw x=%d",w,x); check(nm,&v,1); }
            eraseSprite(1);
            check("erase -> base", NULL, 0);
            freeSprite(1);
        }
        free(sd);
    }
}

// ---- documented limitation: fully on-screen ODD X drops the rightmost column
static void test_oddx_limitation(void){
    printf("documented limitation: on-screen odd-X drops the rightmost column:\n");
    reset();
    int w=16,h=4; unsigned char *sd=solid(w,h,7);   // solid so the column is visible
    loadSprite(0,w,h,sd);
    drawSprite(0,11,20,false);                       // odd X, fully on-screen
    int rightmost = 20*SCREENWIDTH + (11+w-1);        // pixel (26,20)
    int bg = (rightmost&1)?(base[rightmost>>1]>>4)&0xF:base[rightmost>>1]&0xF;
    tests++;
    // Dropped column shows background (== bg, != the sprite colour 7).
    if(gp(rightmost)==bg && bg!=7){ printf("  PASS  rightmost column dropped (shows bg) as documented\n"); }
    else { fails++; printf("  FAIL  rightmost column = %d, expected bg %d (sprite colour 7)\n", gp(rightmost), bg); }
    freeSprite(0); free(sd);
}

// ---- Bug A: partial-off-screen sprite keeps true position through refresh ----
static void test_clamp_teleport(void){
    printf("Bug A (clamp teleport): partial-off-left sprite survives refreshSprites:\n");
    reset();
    int w=16,h=6; unsigned char *sd=distinct(w,h);
    loadSprite(0,w,h,sd);
    drawSprite(0,-5,3,false);
    vis_t v={sd,w,h,-5,3};
    check("draw at x=-5", &v, 1);
    refreshSprites();
    check("after refresh (must stay at x=-5)", &v, 1);
    freeSprite(0); free(sd);
}

// ---- Bug B: bring a sprite back from off-screen UNDER a higher sprite ----
static void test_bringback(void){
    printf("Bug B (bring-back under higher sprite):\n");
    reset();
    unsigned char *a=solid(16,4,1), *b=solid(16,4,2);
    loadSprite(0,16,4,a); loadSprite(1,16,4,b);
    drawSprite(0,10,20,false);      // A lower
    drawSprite(1,30,20,false);      // B higher, no overlap yet
    moveSprite(0,200,20);           // A fully off-screen
    moveSprite(0,25,20);            // A back, overlapping B -> B must stay on top
    vis_t v[2]={ {a,16,4,25,20}, {b,16,4,30,20} };   // z-order: A then B
    check("A back at 25 under B", v, 2);
    freeSprite(0); freeSprite(1); free(a); free(b);
}

// ---- Bug C: hide a lower sprite; higher overlapping sprite stays intact ----
static void test_hide_hole(void){
    printf("Bug C (hideSprite leaves no hole in higher sprite):\n");
    reset();
    unsigned char *a=solid(16,4,1), *b=solid(16,4,2);
    loadSprite(0,16,4,a); loadSprite(1,16,4,b);
    drawSprite(0,10,20,false);      // A lower
    drawSprite(1,18,20,false);      // B higher, overlaps 18..25
    hideSprite(0);                  // hide A -> only B remains, intact
    vis_t v={b,16,4,18,20};
    check("after hide(A), B intact", &v, 1);
    freeSprite(0); freeSprite(1); free(a); free(b);
}

// ---- freeSprite leaves no hole in a higher sprite ----
static void test_free_hole(void){
    printf("freeSprite leaves no hole in higher sprite:\n");
    reset();
    unsigned char *a=solid(16,4,1), *b=solid(16,4,2);
    loadSprite(0,16,4,a); loadSprite(1,16,4,b);
    drawSprite(0,10,20,false);
    drawSprite(1,18,20,false);
    freeSprite(0);
    vis_t v={b,16,4,18,20};
    check("after free(A), B intact", &v, 1);
    freeSprite(1); free(a); free(b);
}

// ---- moveSprite keeps z-order when a lower sprite slides under a higher one --
static void test_move_zorder(void){
    printf("moveSprite: lower sprite slides under higher, higher stays on top:\n");
    reset();
    unsigned char *a=solid(16,6,1), *b=solid(16,6,2);
    loadSprite(0,16,6,a); loadSprite(1,16,6,b);
    drawSprite(0,10,20,false);      // A lower
    drawSprite(1,30,20,false);      // B higher
    moveSprite(0,20,20);            // A now overlaps B (20..35 vs 30..45)
    vis_t v[2]={ {a,16,6,20,20}, {b,16,6,30,20} };
    check("A moved to 20 under B", v, 2);
    freeSprite(0); freeSprite(1); free(a); free(b);
}

int main(void){
    test_edge();
    test_oddx_limitation();
    test_clamp_teleport();
    test_bringback();
    test_hide_hole();
    test_free_hole();
    test_move_zorder();
    printf(fails ? "\n*** %d/%d SCENARIO CHECKS FAILED ***\n" : "\nALL %d SCENARIO CHECKS PASSED\n",
           fails ? fails : tests);
    return fails ? 1 : 0;
}
