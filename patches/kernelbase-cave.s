    .text
    .globl _sw_pre
_sw_pre:                        # SwitchToFiber pre-hook; rcx = new fiber
    movq %gs:0x30,%r10          # TEB
    movq %gs:0x0,%r11
    cmpq (%r10),%r11            # gsbase is the TEB? then the original store suffices
    je 1f
    cmpq $0,0x348(%r10)         # pthread_qos already parked?
    jne 2f
    movq %gs:0x20,%r11
    movq %r11,0x348(%r10)
2:  movq %rcx,%gs:0x20
1:
    .globl _cv_mid
_cv_mid:                        # ConvertThreadToFiberEx post-hook, after the call; rax = fiber
    testq %rax,%rax
    je 1f
    movq %gs:0x30,%r10
    movq %gs:0x0,%r11
    cmpq (%r10),%r11
    je 1f
    cmpq $0,0x348(%r10)
    jne 2f
    movq %gs:0x20,%r11
    movq %r11,0x348(%r10)
2:  movq %rax,%gs:0x20
1:  ret
    .globl _end
_end:
