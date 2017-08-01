# 30jun15abu
# (c) Software Lab. Alexander Burger

(msg 'date " ...")
(bench (do 1000000 (date)))


(msg 'gc " ...")
(gc 3200)

(bench
   (setq Lst
      (make
         (do 10000
            (link (make (do 10000 (link (box))))) ) ) ) )

(bench
   (do 10
      (gc) ) )

(off Lst)

(bench
   (do 10
      (gc) ) )

(msg (heap) " MiB")

# vi:et:ts=3:sw=3
