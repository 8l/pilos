# 08mar17abu
# (c) Software Lab. Alexander Burger

(on *Dbg)

(de task (Key . Prg)
   (nond
      (Prg (del (assoc Key *Run) '*Run))
      ((num? Key) (quit "Bad Key" Key))
      ((assoc Key *Run)
         (push '*Run
            (conc
               (make
                  (when (lt0 (link Key))
                     (link (+ (eval (++ Prg) 1))) ) )
               (ifn (sym? (car Prg))
                  Prg
                  (cons
                     (cons 'job
                        (cons
                           (lit
                              (make
                                 (while (atom (car Prg))
                                    (link
                                       (cons (++ Prg) (eval (++ Prg) 1)) ) ) ) )
                           Prg ) ) ) ) ) ) )
      (NIL (quit "Key conflict" Key)) ) )

(de macro "Prg"
   (run (fill "Prg")) )

(de recur recurse
   (run (cdr recurse)) )

(de curry "Z"
   (let ("X" (++ "Z")  "Y" (++ "Z")  "P" (filter pat? "X"))
      (if2 "P" (diff "X" "P")
         (list "Y" (cons 'job (lit (env @)) (fill "Z" "P")))
         (cons "Y" (fill "Z" "P"))
         (list "Y" (cons 'job (lit (env @)) "Z"))
         (cons "Y" "Z") ) ) )

### Definitions ###
(de expr ("F")
   (set "F"
      (list '@ (list 'pass (box (getd "F")))) ) )

(de subr ("F")
   (set "F"
      (getd (cadr (cadr (getd "F")))) ) )

(de undef ("X" "C")
   (when (pair "X")
      (setq  "C" (cdr "X")  "X" (car "X")) )
   (ifn "C"
      (prog1 (val "X") (set "X"))
      (prog1
         (cdr (asoq "X" (val "C")))
         (set "C"
            (delq (asoq "X" (val "C")) (val "C")) ) ) ) )

(de redef "Lst"
   (let ("Old" (car "Lst")  "New" (name "Old"))
      (set
         "New" (getd "Old")
         "Old" "New"
         "Old" (fill (cdr "Lst") "Old") )
      "New" ) )

(de daemon ("X" . Prg)
   (prog1
      (nond
         ((pair "X")
            (or (pair (getd "X")) (expr "X")) )
         ((pair (cdr "X"))
            (method (car "X") (cdr "X")) )
         (NIL
            (method (car "X") (get (or (cddr "X") *Class) (cadr "X"))) ) )
      (con @ (append Prg (cdr @))) ) )

(de patch ("Lst" "Pat" . "Prg")
   (bind (fish pat? "Pat")
      (recur ("Lst")
         (loop
            (cond
               ((match "Pat" (car "Lst"))
                  (set "Lst" (run "Prg")) )
               ((pair (car "Lst"))
                  (recurse @) ) )
            (NIL (cdr "Lst"))
            (T (atom (cdr "Lst"))
               (when (match "Pat" (cdr "Lst"))
                  (con "Lst" (run "Prg")) ) )
            (setq "Lst" (cdr "Lst")) ) ) ) )

(de cache ("Var" X . Prg)
   (let K (cons (char (hash X)) X)
      (nond
         (Prg (caar (idx "Var" K)))
         ((setq "Var" (caar (idx "Var" K T)))
            (set (car K) (run Prg 1)) )
         ((n== "Var" (val "Var"))
            (set "Var" (run Prg 1)) )
         (NIL (val "Var")) ) ) )

### I/O ###
# *PWD *Commit

(on *Commit)

(de abspath (Path Flg)
   (let P
      (if (car (setq Path (split (chop Path) "/")))
         (clip (split (chop *PWD) "/"))
         (++ Path) )
      (for F (clip Path)
         (cond
            ((= F '(".")))
            ((= F '("." "."))
               (setq P (flip (cdr (flip P)))) )
            (T (setq P (conc P (cons F)))) ) )
      (glue "/"
         (if (and P Flg)
            (conc P '(NIL))
            P ) ) ) )

(de info (Path)
   (and (abspath Path) (val (fetch NIL @))) )

(de pwd ()
   (or *PWD "/") )

(de cd (Dir)
   (if Dir
      (let P (abspath Dir T)
         (if (minKey NIL P (pack P `(char T)))
            (setq *PWD P)
            (quit "Directory not found" Dir) ) )
      (off *PWD) )
   (pwd) )

(de dir (Dir Flg)
   (setq Dir (abspath (or Dir ".") T))
   (let N (inc (length Dir))
      (make
         (scan NIL
            '((K V)
               (let L (split (nth (chop K) N) "/")
                  (when (or Flg (<> "." (caar L)))
                     (setq L (pack (car L) (and (cdr L) "/")))
                     (unless (member L (made))
                        (link L) ) ) ) )
            Dir
            (pack Dir `(char T)) ) ) ) )

(redef load Lst
   (for F Lst
      (when (str (setq F (eval F)))
         (if (and (abspath F) (fetch NIL @))
            (setq F @)
            (quit "File not found" F) ) )
      (load F) ) )

(redef in ("@F" . "@Prg")
   (when (str "@F")
      (if (and (abspath "@F") (fetch NIL @))
         (setq "@F" @)
         (quit "File not found" "@F") ) )
   (macro (in '"@F" . "@Prg")) )

(redef out ("@F" . "@Prg")
   (when (str "@F")
      (if (abspath "@F")
         (let P @
            (setq "@F"
               (or
                  (fetch NIL P)
                  (prog1
                     (new T 0)
                     (store NIL P @)
                     (and *Commit (commit)) ) ) ) )
         (quit "Can't create File" "@F") ) )
   (macro (out '"@F" . "@Prg")) )

(de mv (Src Dst)
   (let P (abspath Src)
      (ifn (and P (fetch NIL P))
         (quit "File not found" Src)
         (store NIL (abspath Dst) @)
         (store NIL P NIL)
         (and *Commit (commit)) ) ) )

(de rm (F)
   (let P (abspath F)
      (ifn (and P (fetch NIL P))
         (quit "File not found" F)
         (zap @)
         (store NIL P NIL)
         (and *Commit (commit)) ) ) )


(de tab (Lst . @)
   (for N Lst
      (let V (next)
         (and (gt0 N) (space (- N (length V))))
         (prin V)
         (and (lt0 N) (args) (space (- 0 N (length V)))) ) )
   (prinl) )

(de beep ()
   (prin "^G") )

(de msg (X . @)
   (out NIL
      (print X)
      (pass prinl) )
   X )

(de script (File . @)
   (load File) )

(de pil @
   (pass pack "/.pil/") )

### List ###
(de uniq (Lst)
   (let R NIL
      (filter
         '((X)
            (not (idx 'R (cons (hash X) X) T)) )
         Lst ) ) )

### Symbol ###
(de qsym "Sym"
   (cons (val "Sym") (getl "Sym")) )

(de loc (S X)
   (if (and (str? X) (= S X))
      X
      (and
         (pair X)
         (or
            (loc S (car X))
            (loc S (cdr X)) ) ) ) )

(de local ()
   (symbols (list (car (symbols)))
      (read) ) )

(de import Lst
   (for Sym Lst
      (intern Sym T) )
   Lst )

### OOP ###
(de class Lst
   (let L (val (setq *Class (car Lst)))
      (def *Class
         (recur (L)
            (if (atom (car L))
               (cdr Lst)
               (cons (car L) (recurse (cdr L))) ) ) ) ) )

(de object ("Sym" "Val" . @)
   (putl "Sym")
   (def "Sym" "Val")
   (while (args)
      (put "Sym" (next) (next)) )
   "Sym" )

(de extend X
   (setq *Class (car X)) )

# Class variables
(de var X
   (if (pair (car X))
      (put (cdar X) (caar X) (cdr X))
      (put *Class (car X) (cdr X)) ) )

(de var: X
   (apply meta X This) )

### Math ###
(de scl ("N" . "Prg")
   (if "Prg"
      (let *Scl "N" (run "Prg"))
      (setq *Scl "N") ) )

# (Knuth Vol.2, p.442)
(de ** (X N)  # N th power of X
   (if (ge0 N)
      (let Y 1
         (loop
            (when (bit? 1 N)
               (setq Y (* Y X)) )
            (T (=0 (setq N (>> 1 N)))
               Y )
            (setq X (* X X)) ) )
      0 ) )

# Accumulate
(de accu (Var Key Val)
   (when Val
      (if (assoc Key (val Var))
         (con @ (+ Val (cdr @)))
         (push Var (cons Key Val)) ) ) )

# Flooding Algorithm
(de flood ("Lst" "Fun" "Init")
   (let G (mapcar '(("X") (cons "X" ("Fun" "X"))) "Lst")
      (for L G
         (for X (cdr L)
            (let A (asoq X G)
               (unless (memq (car L) (cdr A))
                  (con A (cons (car L) (cdr A))) ) ) ) )
      (make
         (recur ("Init")
            (for X "Init"
               (unless (memq X (made))
                  (link X)
                  (recurse (cdr (asoq X G))) ) ) ) ) ) )

### Pretty Printing ###
(de pretty (X N)
   (setq N (abs (space (or N 0))))
   (while (and (pair X) (== 'quote (car X)))
      (prin "'")
      (++ X) )
   (cond
      ((atom X) (print X))
      ((memq (car X) '(de dm redef))
         (_pretty
            (spPrt (++ X))
            (spPrt (++ X))
            (prtty1 X N Z) ) )
      ((memq (car X) '(let let?))
         (_pretty
            (cond
               ((atom (car X))
                  (spPrt (++ X))
                  (prtty? (++ X) N) )
               ((>= 12 (size (car X)))
                  (prin " (")
                  (let Z (++ X)
                     (prtty2 Z NIL Z) )
                  (prin ")") )
               (T
                  (nlPrt N)
                  (prin "(")
                  (let Z (++ X)
                     (prtty2 Z (+ N 3) Z) )
                  (prin " )") ) )
            (prtty1 X N Z) ) )
      ((== 'for (car X))
         (_pretty
            (cond
               ((or (atom (car X)) (atom (cdar X)))
                  (spPrt (++ X))
                  (prtty? (++ X) N) )
               ((>= 12 (size (car X)))
                  (spPrt (++ X)) )
               (T
                  (nlPrt N)
                  (prtty0 (++ X) (+ 3 N)) ) )
            (prtty1 X N Z) ) )
      ((== 'if2 (car X))
         (_pretty
            (when (>= 12 (size (head 2 X)))
               (spPrt (++ X))
               (spPrt (++ X)) )
            (prtty1 X N Z) ) )
      ((memq (car X) '(while until do state finally co))
         (prtty3 X N) )
      ((>= 12 (size X))
         (ifn (memq (car X) '(set setq default))
            (print X)
            (prin "(")
            (let Z X
               (printsp (++ X))
               (prtty2 X NIL Z) )
            (prin ")") ) )
      ((memq (car X) '(=: use later recur tab new))
         (_pretty
            (space)
            (print (++ X))
            (prtty1 X N Z) ) )
      ((memq (car X) '(set setq default))
         (_pretty
            (if (cdddr X)
               (prog
                  (nlPrt N)
                  (prtty2 X N Z) )
               (spPrt (++ X))
               (nlPrt1 (++ X) N) ) ) )
      ((memq (car X) '(T NIL ! if ifn when unless case casq with catch push bind job in out))
         (prtty3 X N) )
      (T (prtty0 X N)) ) )

(de _pretty "Prg"
   (prin "(")
   (let Z X
      (print (++ X))
      (run "Prg") )
   (prin " )") )

(de prtty0 (X N)
   (prin "(")
   (let Z X
      (pretty (++ X) (- -3 N))
      (prtty1 X N Z) )
   (prin " )") )

(de prtty1 (X N Z)
   (loop
      (NIL X)
      (T (== Z X) (prin " ."))
      (T (atom X) (prin " . ") (print X))
      (nlPrt1 (++ X) N) ) )

(de prtty2 (X N Z)
   (loop
      (print (++ X))
      (NIL X)
      (T (== Z X) (prin " ."))
      (T (atom X) (prin " . ") (print X))
      (if N
         (prtty? (++ X) N)
         (space)
         (print (++ X)) )
      (NIL X)
      (T (== Z X) (prin " ."))
      (T (atom X) (prin " . ") (print X))
      (if N
         (nlPrt N)
         (space 2) ) ) )

(de prtty3 (X N)
   (prin "(")
   (let Z X
      (print (++ X))
      (when (or (atom (car X)) (>= 12 (size (car X))))
         (spPrt (++ X)) )
      (when X
         (prtty1 X N Z)
         (space) ) )
   (prin ")") )

(de prtty? (X N)
   (ifn (or (atom X) (>= 12 (size X)))
      (nlPrt1 X N)
      (spPrt X) ) )

(de spPrt (X)
   (space)
   (print X) )

(de nlPrt (N)
   (prinl)
   (space (+ 3 N)) )

(de nlPrt1 (X N)
   (prinl)
   (pretty X (+ 3 N)) )

(de pp ("X" C)
   (let *Dbg NIL
      (pretty
         (if (or C (pair "X"))
            (cons 'dm "X"
               (if (pair "X")
                  (method (car "X") (cdr "X"))
                  (method "X" C) ) )
            (cons 'de "X" (val "X")) ) )
      (prinl)
      "X" ) )

(de show ("X" . @)
   (let *Dbg NIL
      (setq "X" (pass get "X"))
      (when (sym? "X")
         (print "X" (val "X"))
         (prinl)
         (maps
            '((X)
               (space 3)
               (if (atom X)
                  (println X)
                  (println (cdr X) (car X)) ) )
            "X" ) )
      "X" ) )

(de view (X Y)
   (let *Dbg NIL
      (if (=T Y)
         (let N 0
            (recur (N X)
               (when X
                  (recurse (+ 3 N) (cddr X))
                  (space N)
                  (println (car X))
                  (recurse (+ 3 N) (cadr X)) ) ) )
         (let Z X
            (loop
               (T (atom X) (println X))
               (if (atom (car X))
                  (println '+-- (++ X))
                  (print '+---)
                  (view
                     (++ X)
                     (append Y (cons (if X "|   " "    "))) ) )
               (NIL X)
               (mapc prin Y)
               (T (== Z X) (println '*))
               (println '|)
               (mapc prin Y) ) ) ) ) )

### Check ###
# Assertions
(de assert Prg
   (when *Dbg
      (let A (if (cdr Prg) (cons 'and Prg) (car Prg))
         (cons
            (list 'unless A
               (list 'quit "'assert' failed" (lit A)) ) ) ) ) )

# Unit tests
(de test (Pat . Prg)
   (bind (fish pat? Pat)
      (unless (match Pat (run Prg 1))
         (msg Prg)
         (quit "'test' failed" Pat) ) ) )

# vi:et:ts=3:sw=3