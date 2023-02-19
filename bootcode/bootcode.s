//
//  bootcode.s
//  bootcode
//
//  Created by David Albert on 2/18/23.
//

mov x0, #2
add x0, x0, #2
hvc #0xcafe
