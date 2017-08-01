# 04oct15abu
# (c) Software Lab. Alexander Burger

### Global return labels ###
(code 'ret 0)
   ret
(code 'retEq 0)
   eq
   ret
(code 'retGt 0)
   gt
   ret
(code 'retLt 0)
   lt
   ret
(code 'retNull 0)
   ld E 0
   ret
(code 'retNil 0)
   ld E Nil
   ret
(code 'retT 0)
   ld E TSym
   ret
(code 'retE_E 0)
   ld E (E)  # Get value or CAR
   ret

# PilOS Kernel end
(code 'K_END)

# vi:et:ts=3:sw=3
