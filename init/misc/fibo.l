# 25sep14abu
# (c) Software Lab. Alexander Burger

# Standard version
(de fibo (N)
   (if (>= 2 N)
      1
      (+ (fibo (dec N)) (fibo (- N 2))) ) )

# vi:et:ts=3:sw=3
