//
//  bootcode.s
//  bootcode
//
//  Created by David Albert on 2/18/23.
//

mov     x0, #0x4000 // uart address
mov     x1, 'H'
strb    w1, [x0]
mov     x1, 'e'
strb    w1, [x0]
mov     x1, 'l'
strb    w1, [x0]
mov     x1, 'l'
strb    w1, [x0]
mov     x1, 'o'
strb    w1, [x0]
mov     x1, ' '
strb    w1, [x0]
mov     x1, 'w'
strb    w1, [x0]
mov     x1, 'o'
strb    w1, [x0]
mov     x1, 'r'
strb    w1, [x0]
mov     x1, 'l'
strb    w1, [x0]
mov     x1, 'd'
strb    w1, [x0]
mov     x1, '!'
strb    w1, [x0]
mov     x1, '\n'
strb    w1, [x0]

mov     x0, #2
add     x0, x0, #2
hvc     #0xcafe
