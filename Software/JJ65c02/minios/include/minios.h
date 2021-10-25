.ifndef _MINIOS_H_
_MINIOS_H_ = 1


DEBOUNCE = 150                                  ; 150ms seems about right

.import __RAM_START__

PROGRAM_START = $0500                           ; memory location for user programs
PROGRAM_END = $8000                             ; End of RAM

.endif
