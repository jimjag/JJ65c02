// ================= END EXTRACTED CODE =================
//
// Differential simulation of the sprite subsystem.
//
// The incremental engine (drawSprite/eraseSprite/moveSprite/hideSprite/
// freeSprite/refreshSprites) must keep the framebuffer identical to what a
// from-scratch repaint of all visible sprites in z-order would produce. We
// drive a long randomised sequence of the safe API over NS overlapping sprites
// and, after EVERY operation, compare the incrementally-maintained framebuffer
// to a clean repaint done by the real renderer itself (clean_repaint) — a
// model-free oracle. An independent z-order model (refz/shown/mx/my) decides
// which sprites are visible and in what order.
//
// Usage: ./_sim [iterations]     (default 60000)   exit 0 = all match.

#define NS 10                                   // sprite slots exercised

static unsigned char *pat[MAXSPRITES];          // source pixels (0..15 / 0xFF)
static int   sw_[MAXSPRITES], sh_[MAXSPRITES];  // widths/heights
static int   mx[MAXSPRITES], my[MAXSPRITES];    // model positions (true x/y)
static int   loaded[MAXSPRITES], active[MAXSPRITES], shown[MAXSPRITES];
static int   refz[MAXSPRITES], refzc;           // independent z-order list
static unsigned char base[FBYTES];              // background under all sprites

static int gpx(unsigned char *b, int p){ return (p&1)?(b[p>>1]>>4)&0xF:b[p>>1]&0xF; }
static void spx(unsigned char *b, int p, int v){
    if(p&1) b[p>>1]=(b[p>>1]&0x0F)|((v&0xF)<<4);
    else    b[p>>1]=(b[p>>1]&0xF0)|(v&0xF);
}
static int onscreen(int x,int y,int w,int h){
    return !(x<=-w || x>=SCREENWIDTH || y>=SCREENHEIGHT || y<=-h);
}
static void refz_add(int s){ refz[refzc++]=s; }
static void refz_del(int s){
    for(int i=0;i<refzc;i++) if(refz[i]==s){ for(int j=i;j<refzc-1;j++) refz[j]=refz[j+1]; refzc--; return; }
}

// deterministic PRNG (fixed seed -> reproducible failures)
static uint64_t rng=0x123456789abcdef0ULL;
static uint64_t rnd(void){ rng^=rng<<13; rng^=rng>>7; rng^=rng<<17; return rng; }
static int rrange(int lo,int hi){ return lo + (int)(rnd()%(uint64_t)(hi-lo+1)); }

static void mk_pattern(int sn,int w,int h){
    pat[sn]=malloc(w*h);
    for(int r=0;r<h;r++) for(int c=0;c<w;c++){
        // transparent holes (let lower sprites show through); edge columns kept opaque
        int transp = (((r+c+sn)%3)==0) && c!=0 && c!=w-1;
        pat[sn][r*w+c] = transp ? 0xFF : (unsigned char)(1 + ((sn*5+r*3+c*2)%15));
    }
    sw_[sn]=w; sh_[sn]=h;
}
// Full position range: fully on-screen, partially clipped (all four edges), and
// fully off-screen — all X parities.
static int gen_x(int w){ return rrange(-w-2, SCREENWIDTH+2); }
static int gen_y(int h){ return rrange(-h-2, SCREENHEIGHT+2); }

// ---- ground truth: repaint from base in z-order using the REAL renderer ----
static unsigned char clean[FBYTES];
static unsigned char snap_bgv[MAXSPRITES];
static short snap_x[MAXSPRITES], snap_y[MAXSPRITES];
static uint64_t snap_bg[MAXSPRITES][2][16];
static int snap_do[MAXSPRITES], snap_doc;
// Because clean_repaint mutates sprite state (bgValid/bgrnd/x/y) and the
// framebuffer, we snapshot the incremental state, repaint, compare, and
// restore — so the incremental run continues untouched.
static void snapshot(void){
    snap_doc=draw_order_count; memcpy(snap_do,draw_order,sizeof(snap_do));
    for(int s=0;s<NS;s++){ if(!sprites[s]){snap_bgv[s]=2;continue;}
        snap_bgv[s]=sprites[s]->bgValid; snap_x[s]=sprites[s]->x; snap_y[s]=sprites[s]->y;
        int ch=sprites[s]->width/16;
        for(int k=0;k<ch;k++) if(sprites[s]->bgrnd[k]) memcpy(snap_bg[s][k],sprites[s]->bgrnd[k],8*sprites[s]->height);
    }
}
static void restore(void){
    draw_order_count=snap_doc; memcpy(draw_order,snap_do,sizeof(snap_do));
    for(int s=0;s<NS;s++){ if(snap_bgv[s]==2||!sprites[s]) continue;
        sprites[s]->bgValid=snap_bgv[s]; sprites[s]->x=snap_x[s]; sprites[s]->y=snap_y[s];
        int ch=sprites[s]->width/16;
        for(int k=0;k<ch;k++) if(sprites[s]->bgrnd[k]) memcpy(sprites[s]->bgrnd[k],snap_bg[s][k],8*sprites[s]->height);
    }
}
static void clean_repaint(void){
    for(int s=0;s<NS;s++) if(sprites[s]) sprites[s]->bgValid=false;
    memcpy(fb,base,FBYTES);
    for(int zi=0;zi<refzc;zi++){ int s=refz[zi]; if(shown[s]) drawSprite(s,mx[s],my[s],false); }
    memcpy(clean,fb,FBYTES);
}

static long g_it=-1;
static const char *lastop="init"; static int lastsn=-1,lastx=0,lasty=0;
static int checks=0, cleanfails=0;
static void verify(void){    checks++;
    unsigned char inc[FBYTES]; memcpy(inc,fb,FBYTES);   // incremental result
    snapshot();
    clean_repaint();                                    // ground truth (same renderer)
    int diff = memcmp(inc,clean,FBYTES)!=0;
    memcpy(fb,inc,FBYTES); restore();                   // put incremental state back
    TD_FRAME(); TD_DELAY(3);                             // watch it (no-op if headless)
    if(diff){
        cleanfails++;
        if(cleanfails==1){
            int fp=-1; for(int p=0;p<SCREENWIDTH*SCREENHEIGHT;p++) if(gpx(inc,p)!=gpx(clean,p)){fp=p;break;}
            int fy=fp/SCREENWIDTH;
            printf("FIRST DIVERGENCE at it=%ld op=%s sn=%d (%d,%d): pixel(x=%d,y=%d) incremental=%d cleanRepaint=%d\n",
                   g_it,lastop,lastsn,lastx,lasty,fp%SCREENWIDTH,fy,gpx(inc,fp),gpx(clean,fp));
            printf("  draw_order(low->high): ");
            for(int i=0;i<draw_order_count;i++){int s=draw_order[i];
                printf("s%d@(%d,%d,w%d,h%d,%s) ",s,sprites[s]->x,sprites[s]->y,sprites[s]->width,sprites[s]->height,(sprites[s]->x&1)?"odd":"even");}
            printf("\n  row y=%d x=%d..%d  incremental: ",fy,fp%SCREENWIDTH-2,fp%SCREENWIDTH+10);
            for(int x=fp%SCREENWIDTH-2;x<fp%SCREENWIDTH+10;x++) printf("%X",gpx(inc,fy*SCREENWIDTH+x));
            printf("\n  row y=%d x=%d..%d  cleanRepaint: ",fy,fp%SCREENWIDTH-2,fp%SCREENWIDTH+10);
            for(int x=fp%SCREENWIDTH-2;x<fp%SCREENWIDTH+10;x++) printf("%X",gpx(clean,fy*SCREENWIDTH+x));
            printf("\n");
        }
    }
}

static void do_move(int sn){
    int w=sw_[sn],h=sh_[sn]; int x=gen_x(w), y=gen_y(h);
    lastop="move"; lastsn=sn; lastx=x; lasty=y;
    if(!loaded[sn]) return;
    moveSprite(sn,x,y);
    if(!active[sn]){ active[sn]=1; refz_add(sn); }   // first draw -> appended on top
    mx[sn]=x; my[sn]=y; shown[sn]=onscreen(x,y,w,h);
}
static void do_hide(int sn){
    lastop="hide"; lastsn=sn; lastx=lasty=0;
    if(!loaded[sn]) return;
    hideSprite(sn);
    shown[sn]=0;                                      // keeps its z-slot (still in refz)
}
static void do_free(int sn){
    lastop="free"; lastsn=sn; lastx=lasty=0;
    if(!loaded[sn]) return;
    freeSprite(sn);
    if(active[sn]) refz_del(sn);
    active[sn]=0; loaded[sn]=0; shown[sn]=0;
}
static void do_reload(int sn){
    lastop="reload"; lastsn=sn; lastx=lasty=0;
    if(loaded[sn] && active[sn]) refz_del(sn);        // loadSprite frees the existing object first
    free(pat[sn]);
    int w=(rnd()&1)?SPRITE16_WIDTH:SPRITE32_WIDTH; int h=rrange(4,10);
    mk_pattern(sn,w,h);
    loadSprite(sn,w,h,pat[sn]);
    loaded[sn]=1; active[sn]=0; shown[sn]=0;
}
static void do_refresh(void){
    lastop="refresh"; lastsn=-1; lastx=lasty=0;
    refreshSprites();
}

int main(int argc, char **argv){
    long iters = argc>1 ? atol(argv[1]) : 60000;
    for(int i=0;i<FBYTES;i++) base[i]=(unsigned char)((i*11+3)&0xFF);
    memcpy(fb,base,FBYTES);
    TD_OPEN("sprite tests: differential simulation");

    // Phase 1: load NS sprites (objects only, not yet drawn).
    for(int sn=0; sn<NS; sn++){
        int w=(sn&1)?SPRITE16_WIDTH:SPRITE32_WIDTH; int h=rrange(4,10);
        mk_pattern(sn,w,h);
        loadSprite(sn,w,h,pat[sn]);
        loaded[sn]=1;
    }
    verify();

    // Phase 2: randomised safe-API sequence (move / hide / free / reload / refresh)
    // over overlapping sprites at every on/partial/off-screen position + parity.
    for(long it=0; it<iters; it++){
        g_it=it;
        int sn=rrange(0,NS-1);
        int r=rrange(0,99);
        if(r<58)      do_move(sn);
        else if(r<72) do_hide(sn);
        else if(r<80) do_free(sn);
        else if(r<90) do_reload(sn);
        else          do_refresh();
        verify();
    }
    printf("Phase 2 (%ld ops, move/hide/free/reload/refresh): %d checks, %d divergences\n",
           iters, checks, cleanfails);

    // Phase 3: lone-sprite DIRECT drawSprite(erase=false) with always-overlapping
    // 1px steps — exercises the self-overlap auto-erase; must stay a single image.
    {
        for(int sn=0;sn<NS;sn++) if(loaded[sn]) do_free(sn);
        memcpy(fb,base,FBYTES);
        refzc=0;
        int sn=0, w=SPRITE16_WIDTH, h=8; mk_pattern(sn,w,h);
        loadSprite(sn,w,h,pat[sn]); loaded[sn]=1;
        refz_add(sn); active[sn]=1; shown[sn]=1;
        int c0=checks, cf0=cleanfails;
        for(int step=0; step<400; step++){
            int t=step%60; int x=10 + (t<30?t:59-t); int y=5;   // 1px ping-pong
            drawSprite(sn,x,y,false);
            mx[sn]=x; my[sn]=y; shown[sn]=1;
            verify();
        }
        printf("Phase 3 (overlapping direct-draw): %d checks, %d divergences\n", checks-c0, cleanfails-cf0);
    }

    printf(cleanfails ? "\n*** %d DIVERGENCE(S) ***\n" : "\nALL %d CHECKS PASSED (incremental == cleanRepaint)\n",
           cleanfails ? cleanfails : checks);
    TD_CLOSE();
    return cleanfails ? 1 : 0;
}
