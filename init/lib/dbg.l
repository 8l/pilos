# 03mar17abu
# (c) Software Lab. Alexander Burger

### Debug ###
`*Dbg

############ lib/led.l ############
# Line editor
# vi-mode, just a subset:
#  - Only single-key commands
#  - No repeat count

(mapc undef
   '(*Led fkey revise) )

(setq
   "Line"      NIL      # Holds current input line
   "LPos"      1        # Position in line (1 .. length)
   "HPos"      1        # Position in history
   "UndoLine"  NIL      # Undo
   "UndoPos"   0
   "Line1"     NIL      # Initial line
   "Insert"    T        # Insert mode flag
   "FKey"      NIL      # Function key bindings
   "Clip"      NIL      # Cut/Copy/Paste buffer
   "Item"      NIL      # Item to find
   "Found"     NIL      # Find stack
   "Complete"  NIL      # Input completion

   "HistMax"   1000     # History limit

   *History             # History of input lines
   (in (pil "history")
      (make (until (eof) (link (line T)))) )
   "Hist0"     *History )


# Basic editing routine
(de chgLine (L N)
   (let (D (length "Line")  Tsm)
      (for (P (dec "LPos") (gt0 P) (dec P))  # To start of old line
         (unless
            (and
               *Tsm
               (= "\"" (get "Line" P))
               (skipQ "LPos" P "Line") )
            (prin "^H") ) )
      (for (P . C) (setq "Line" L)  # Output new line
         (cond
            ((> " " C)
               (dec 'D)
               (prin "_") )
            ((or (not *Tsm) (<> "\"" C) (escQ P L))
               (dec 'D)
               (prin C) )
            (T
               (prin
                  (and Tsm (cdr *Tsm))
                  (unless (skipQ N P L)
                     (dec 'D)
                     C )
                  (and (onOff Tsm) (car *Tsm)) ) ) ) )
      (and Tsm (prin (cdr *Tsm)))
      (space D)  # Clear rest of old line
      (do D (prin "^H"))
      (setq "LPos" (inc (length L)))
      (until (= N "LPos")  # To new position
         (unless
            (and
               *Tsm
               (= "\"" (get "Line" "LPos"))
               (skipQ N "LPos" "Line") )
            (prin "^H") )
         (dec '"LPos") ) ) )

# Skipped double quote
(de skipQ (N P L)
   (nor
      (>= (inc N) P (dec N))
      (= "\""  (get L (dec P)))
      (= "\"" (get L (inc P)))
      (escQ P L) ) )

# Escaped double quote
(de escQ ()
   (let Esc NIL
      (for I (dec P)
         ((if (= "\\" (get L I)) onOff off) Esc) ) ) )

# Check for delimiter
(de delim? (C)
   (member C '`(chop '" ^I^J^M\"'()[]`~")) )

# Move left
(de lMove ()
   (chgLine "Line" (max 1 (dec "LPos"))) )

# Move to beginning
(de bMove ()
   (chgLine "Line" 1) )

# Move right
(de rMove (F)
   (chgLine "Line"
      (min
         (inc "LPos")
         (if F
            (inc (length "Line"))
            (length "Line") ) ) ) )

# Move to end of line
(de eMove ()
   (chgLine "Line" (length "Line")) )

# Move beyond end of line
(de xMove ()
   (chgLine "Line" (inc (length "Line"))) )

# Move up
(de uMove ()
   (when (< "HPos" (length *History))
      (setHist (inc "HPos")) ) )

# Move down
(de dMove ()
   (unless (=0 "HPos")
      (setHist (dec "HPos")) ) )

# Move word left
(de lWord ()
   (use (N L)
      (chgLine "Line"
         (if (>= 1 (setq N "LPos"))
            1
            (loop
               (T (= 1 (dec 'N)) 1)
               (setq L (nth "Line" (dec N)))
               (T (and (delim? (car L)) (not (delim? (cadr L))))
                  N ) ) ) ) ) )

# Move word right
(de rWord ()
   (use (M N L)
      (setq M (length "Line"))
      (chgLine "Line"
         (if (<= M (setq N "LPos"))
            M
            (loop
               (T (= M (inc 'N)) M)
               (setq L (nth "Line" (dec N)))
               (T (and (delim? (car L)) (not (delim? (cadr L))))
                  N ) ) ) ) ) )

# Match left parenthesis
(de lPar ()
   (let (N 1  I (dec "LPos"))
      (loop
         (T (=0 I))
         (case (get "Line" I)
            (")" (inc 'N))
            ("(" (dec 'N)) )
         (T (=0 N) (chgLine "Line" I))
         (dec 'I) ) ) )

# Match right parenthesis
(de rPar ()
   (let (N 1  I (inc "LPos"))
      (loop
         (T (> I (length "Line")))
         (case (get "Line" I)
            ("(" (inc 'N))
            (")" (dec 'N)) )
         (T (=0 N) (chgLine "Line" I))
         (inc 'I) ) ) )

# Clear to end of line
(de clrEol ()
   (let N (dec "LPos")
      (if (=0 N)
         (chgLine NIL 1)
         (chgLine (head N "Line") N) ) ) )

# Insert a char
(de insChar (C)
   (chgLine (insert "LPos" "Line" C) (inc "LPos")) )

(de del1 (L)
   (ifn (nth L "LPos")
      L
      (setq "Clip" (append "Clip" (list (get L "LPos"))))
      (remove "LPos" L) ) )

# Delete a char
(de delChar ()
   (use L
      (off "Clip")
      (chgLine
         (setq L (del1 "Line"))
         (max 1 (min "LPos" (length L))) ) ) )

# Delete a word (F: with trailing blank)
(de delWord (F)
   (let L "Line"
      (off "Clip")
      (ifn (= "(" (get L "LPos"))
         (while (and (nth L "LPos") (not (delim? (get L "LPos"))))
            (setq L (del1 L)) )
         (for (N 1 (and (setq L (del1 L)) (< 0 N)))
            (case (get L "LPos")
               ("(" (inc 'N))
               (")" (dec 'N)) ) ) )
      (and
         F
         (sp? (get L "LPos"))
         (setq L (del1 L)) )
      (chgLine L (max 1 (min "LPos" (length L)))) ) )

# Replace char
(de rplChar (C)
   (chgLine
      (insert "LPos" (remove "LPos" "Line") C)
      "LPos" ) )

# Undo mechanism
(de doUndo ()
   (setq  "UndoLine" "Line"  "UndoPos"  "LPos") )

# Paste clip
(de doPaste ()
   (if (= 1 "LPos")
      (chgLine (append "Clip" "Line") 1)
      (chgLine
         (append
            (head (dec "LPos") "Line")
            "Clip"
            (nth "Line" "LPos") )
         (+ "LPos" (length "Clip") -1) ) ) )

# Set history line
(de setHist (N)
   (chgLine
      (if (=0 (setq "HPos" N))
         "Line1"
         (chop (get *History "HPos")) )
      1 ) )

# Searching
(de ledSearch (L)
   (let (H (nth *History (inc "HPos"))  S (find '((X) (match "Item" (chop X))) H))
      (chgLine
         (ifn S
            (prog (beep) L)
            (push '"Found" "HPos")
            (inc '"HPos" (index S H))
            (chop S) )
         1 ) ) )

# TAB expansion
(de expandTab ()
   (let ("L" (head (dec "LPos") "Line")  "S" "L")
      (while (find "skipFun" "S")
         (++ "S") )
      (ifn "S"
         (prog
            (off "Complete")
            (do 3 (insChar " ")) )
         (ifn
            (default "Complete"
               (let "N" (inc (length "S"))
                  (mapcar
                     '((X)
                        (setq X
                           (nth
                              (mapcan
                                 '((C)
                                    (if (or (= "\\" C) (delim? C))
                                       (list "\\" C)
                                       (cons C) ) )
                                 (chop X) )
                              "N" ) )
                        (cons
                           (+ "LPos" (length X))
                           (append "L" X (nth "Line" "LPos")) ) )
                     ("tabFun" (pack "S")) ) ) )
            (beep)
            (chgLine (cdar "Complete") (caar "Complete"))
            (rot "Complete") ) ) ) )

# Insert mode
(de insMode ("C")
   (if (= "C" "^I")
      (expandTab)
      (off "Complete")
      (case "C"
         (("^H" "^?")
            (if (> "LPos" 1)
               (chgLine (remove (dec "LPos") "Line") (dec "LPos"))
               (beep) ) )
         ("^V" (insChar (key)))
         ("^E" (and edit (edit '*History)))
         ("^F" (saveHistory))
         ("^D" (and (=1 "LPos") (bye)))
         ("^["
            (loop
               (NIL
                  (make
                     (while (and (setq "C" (key 40)) (<> "C" "^["))
                        (link "C") ) )
                  (off "Insert")
                  (lMove) )
               (when (assoc (pack "^[" @) "FKey")
                  (let *Dbg "*Dbg" (run (cdr @))) )
               (NIL "C") ) )
         (T
            (if (assoc "C" "FKey")
               (let *Dbg "*Dbg" (run (cdr @)))
               (when (= "C" ")")
                  (chgLine "Line" (prog1 "LPos" (lPar) (wait 200))) )
               (insChar "C") ) ) ) ) )

# Command mode
(de cmdMode ("C")
   (case "C"
      ("g" (prinl) (println "Clip"))
      ("$" (eMove))
      ("%"
         (case (get "Line" "LPos")
            (")" (lPar))
            ("(" (rPar))
            (T (beep)) ) )
      ("/"
         (let "L" "Line"
            (_getLine '("/") '((C) (= C "/")))
            (unless (=T "Line")
               (setq "Item" (append '(@) (cdr "Line") '(@)))
               (ledSearch "L")
               (off "Insert") ) ) )
      ("0" (bMove))
      ("A" (doUndo) (xMove) (on "Insert"))
      ("a" (doUndo) ((if (= "LPos" (length "Line")) xMove rMove)) (on "Insert"))
      ("b" (lWord))
      ("c" (doUndo) (delWord NIL) (on "Insert"))
      ("C" (doUndo) (clrEol) (xMove) (on "Insert"))
      ("d" (doUndo) (delWord T))
      ("D" (doUndo) (clrEol))
      ("f"
         (ifn (setq "C" (index (key) (nth "Line" (inc "LPos"))))
            (beep)
            (chgLine "Line" (+ "C" "LPos")) ) )
      ("h" (lMove))
      ("i" (doUndo) (on "Insert"))
      ("I" (doUndo) (bMove) (on "Insert"))
      ("j" (dMove))
      ("k" (uMove))
      ("l" (rMove))
      ("n" (ledSearch "Line"))
      ("N" (if "Found" (setHist (++ "Found")) (beep)))
      ("p" (doUndo) ((if (= "LPos" (length "Line")) xMove rMove)) (doPaste))
      ("P" (doUndo) (doPaste))
      ("r" (ifn "Line" (beep) (doUndo) (rplChar (key))))
      ("s" (doUndo) (delChar) (on "Insert"))
      ("S" (doUndo) (chgLine NIL 1) (on "Insert"))
      ("U" (setHist "HPos"))
      ("u"
         (let ("L" "Line"  "P" "LPos")
            (chgLine "UndoLine" "UndoPos")
            (setq  "UndoLine" "L"  "UndoPos" "P") ) )
      ("w" (rWord))
      ("x" (doUndo) (delChar))
      ("X" (lMove) (doUndo) (delChar))
      ("~"
         (doUndo)
         (rplChar
            ((if (low? (setq "C" (get "Line" "LPos"))) uppc lowc) "C") )
         (rMove) )
      (T (beep)) ) )

# Get a line from console
(de _getLine ("L" "skipFun")
   (use "C"
      (chgLine "L" (inc (length "L")))
      (on "Insert")
      (until (member (setq "C" (let *Dbg "*Dbg" (key))) '("^J" "^M"))
         (when (= "C" "^X")
            (prin (cdr *Tsm))
            (prinl)
            (quit) )
         ((if "Insert" insMode cmdMode) "C") )
      (eMove) ) )

# Function keys
(de fkey (Key . Prg)
   (setq "FKey"
      (cond
         ((not Key) "FKey")
         ((not Prg) (delete (assoc Key "FKey") "FKey"))
         ((assoc Key "FKey")
            (cons (cons Key Prg) (delete @ "FKey")) )
         (T (cons (cons Key Prg) "FKey")) ) ) )

# Main editing functions
(de _led ("Line1" "tabFun" "skipFun")
   (default "tabFun"
      '((S)
         (conc
            (filter '((X) (pre? S X)) (all))
            (let P (rot (split (chop S) "/"))
               (setq
                  S (pack (car P))
                  P (and (cdr P) (pack (glue "/" @) "/")) )
               (extract '((X) (and (pre? S X) (pack P X)))
                  (dir P T) ) ) ) ) )
   (setq "LPos" 1  "HPos" 0)
   (_getLine "Line1" (or "skipFun" delim?))
   (prinl (cdr *Tsm)) )

(de revise ("X" "tabFun" "skipFun")
   (let ("*Dbg" *Dbg  *Dbg NIL)
      (_led (chop "X") "tabFun" "skipFun")
      (pack "Line") ) )

(de saveHistory ()
   (unless (= *History "Hist0")
      (out (pil "history")
         (mapc prinl *History) ) ) )

# Enable line editing
(de *Led
   (let ("*Dbg" *Dbg  *Dbg NIL)
      (push1 '*Bye '(saveHistory))
      (_led)
      (let L (pack "Line")
         (or
            (>= 3 (length "Line"))
            (sp? (car "Line"))
            (= L (car *History))
            (push '*History L) )
         (and (nth *History "HistMax") (con @))
         L ) ) )

(mapc zap
   (quote
      chgLine skipQ escQ delim? lMove bMove rMove eMove xMove uMove dMove lWord
      rWord lPar rPar clrEol insChar del1 delChar delWord rplChar doUndo doPaste
      setHist ledSearch expandTab insMode cmdMode _getLine _led saveHistory ) )

(====)
############ lib/ed.l ############
# Structure Editor
(setq *Clip)

(de ed ("X" "C")
   (when (pair "X")
      (setq  "C" (cdr "X")  "X" (car "X")) )
   (catch NIL
      (let (*Dbg NIL  "Done")
         (ifn "C"
            (set "X" (_ed (val "X")))
            (and
               (asoq "X" (val "C"))
               (con @ (_ed (cdr @))) ) )
         (pp "X" "C") ) ) )

(de _ed (X)
   (use C
      (loop
         (T "Done" X)
         (pretty (car X))
         (prinl)
         (T (member (setq C (key)) '("^H" "^?")) X)
         (T (= C "^I") (on "Done") X)
         (setq X
            (if (>= "9" C "1")
               (cons
                  (head (setq C (format  C)) X)
                  (nth X (inc C)) )
               (case (uppc C)
                  (("^M" "^J") (cons (_ed (car X)) (cdr X)))
                  ("^[" (throw))
                  (" " (cons (car X) (_ed (cdr X))))
                  ("D" (cdr X))
                  ("I" (prin "Insert:") (cons (read) X))
                  ("R" (prin "Replace:") (cons (read) (cdr X)))
                  ("X" (setq *Clip (car X)) (cdr X))
                  ("C" (setq *Clip (car X)) X)
                  ("V" (cons *Clip X))
                  ("0" (append (car X) (cdr X)))
                  ("B"
                     (if (== '! (caar X))
                        (cons (cdar X) (cdr X))
                        (cons (cons '! (car X)) (cdr X)) ) )
                  (T X) ) ) ) ) ) )

(====)
############ lib/debug.l ############
# Prompt
(de *Prompt
   (unless (== 'pico (car (symbols)))
      (car (symbols)) ) )

(de more ("M" "Fun")
   (let *Dbg NIL
      (if (pair "M")
         ((default "Fun" print) (++ "M"))
         (println (type "M"))
         (setq
            "Fun" (list '(X) (list 'pp 'X (lit "M")))
            "M" (mapcar car (filter pair (val "M"))) ) )
      (loop
         (T (atom "M") (prinl))
         (T (line) T)
         ("Fun" (++ "M")) ) ) )

(de less (X)
   (if (atom X)
      X
      (cons
         (less (++ X))
         (if (atom X)
            X
            (cons
               (less (++ X))
               (and X '(..)) ) ) ) ) )

(de what (S)
   (let *Dbg NIL
      (setq S (chop S))
      (filter
         '(("X") (match S (chop "X")))
         (all) ) ) )

(de who ("X" . "*Prg")
   (let (*Dbg NIL  "Who" '("Who" @ @@ @@@))
      (make (mapc "who" (all))) ) )

(de "who" ("Y")
   (unless (or (ext? "Y") (memq "Y" "Who"))
      (push '"Who" "Y")
      (ifn (= `(char "+") (char "Y"))
         (and (pair (val "Y")) ("nest" @) (link "Y"))
         (for "Z" (pair (val "Y"))
            (if (atom "Z")
               (and ("match" "Z") (link "Y"))
               (when ("nest" (cdr "Z"))
                  (link (cons (car "Z") "Y")) ) ) )
         (maps
            '(("Z")
               (if (atom "Z")
                  (and ("match" "Z") (link "Y"))
                  (when ("nest" (car "Z"))
                     (link (cons (cdr "Z") "Y")) ) ) )
            "Y" ) ) ) )

(de "nest" ("Y")
   ("nst1" "Y")
   ("nst2" "Y") )

(de "nst1" ("Y")
   (let "Z" (setq "Y" (strip "Y"))
      (loop
         (T (atom "Y") (and (sym? "Y") ("who" "Y")))
         (and (sym? (car "Y")) ("who" (car "Y")))
         (and (pair (car "Y")) ("nst1" @))
         (T (== "Z" (setq "Y" (cdr "Y")))) ) ) )

(de "nst2" ("Y")
   (let "Z" (setq "Y" (strip "Y"))
      (loop
         (T (atom "Y") ("match" "Y"))
         (T (or ("match" (car "Y")) ("nst2" (car "Y")))
            T )
         (T (== "Z" (setq "Y" (cdr "Y")))) ) ) )

(de "match" ("D")
   (and
      (cond
         ((str? "X") (and (str? "D") (= "X" "D")))
         ((sym? "X") (== "X" "D"))
         (T (match "X" "D")) )
      (or
         (not "*Prg")
         (let *Dbg (up 2 *Dbg) (run "*Prg")) ) ) )

(de has ("X")
   (let *Dbg NIL
      (filter
         '(("S") (= "X" (val "S")))
         (all) ) ) )

(de can (X)
   (let *Dbg NIL
      (extract
         '(("Y")
            (and
               (= `(char "+") (char "Y"))
               (asoq X (val "Y"))
               (cons X "Y") ) )
         (all) ) ) )

# Class dependencies
(de dep ("C")
   (let *Dbg NIL
      (dep1 0 "C")
      (dep2 3 "C")
      "C" ) )

(de dep1 (N "C")
   (for "X" (type "C")
      (dep1 (+ 3 N) "X") )
   (space N)
   (println "C") )

(de dep2 (N "C")
   (for "X" (all)
      (when
         (and
            (= `(char "+") (char "X"))
            (memq "C" (type "X")) )
         (space N)
         (println "X")
         (dep2 (+ 3 N) "X") ) ) )

# Inherited methods
(de methods (Obj)
   (make
      (let Mark NIL
         (recur (Obj)
            (for X (val Obj)
               (nond
                  ((pair X) (recurse X))
                  ((memq (car X) Mark)
                     (link (cons (car X) Obj))
                     (push 'Mark (car X)) ) ) ) ) ) ) )

# Single-Stepping
(de _dbg (Lst)
   (or
      (atom (car Lst))
      (num? (caar Lst))
      (flg? (caar Lst))
      (== '! (caar Lst))
      (set Lst (cons '! (car Lst))) ) )

(de _dbg2 (Lst)
   (map
      '((L)
         (if (and (pair (car L)) (flg? (caar L)))
            (map _dbg (cdar L))
            (_dbg L) ) )
      Lst ) )

(de dbg (Lst)
   (when (pair Lst)
      (casq (++ Lst)
         ((case casq state)
            (_dbg Lst)
            (for L (cdr Lst)
               (map _dbg (cdr L)) ) )
         ((cond nond)
            (for L Lst
               (map _dbg L) ) )
         (quote
            (when (fun? Lst)
               (map _dbg (cdr Lst)) ) )
         ((job use let let? recur)
            (map _dbg (cdr Lst)) )
         (loop
            (_dbg2 Lst) )
         ((bind do)
            (_dbg Lst)
            (_dbg2 (cdr Lst)) )
         (for
            (and (pair (car Lst)) (map _dbg (cdar Lst)))
            (_dbg2 (cdr Lst)) )
         (T (map _dbg Lst)) )
      T ) )

(de d () (let *Dbg NIL (dbg ^)))

(de debug ("X" C)
   (ifn (traced? "X" C)
      (let *Dbg NIL
         (when (pair "X")
            (setq C (cdr "X")  "X" (car "X")) )
         (or
            (dbg (if C (method "X" C) (getd "X")))
            (quit "Can't debug" "X") ) )
      (untrace "X" C)
      (debug "X" C)
      (trace "X" C) ) )

(de ubg (Lst)
   (when (pair Lst)
      (map
         '((L)
            (when (pair (car L))
               (when (== '! (caar L))
                  (set L (cdar L)) )
               (ubg (car L)) ) )
         Lst )
      T ) )

(de u () (let *Dbg NIL (ubg ^)))

(de unbug ("X" C)
   (let *Dbg NIL
      (when (pair "X")
         (setq C (cdr "X")  "X" (car "X")) )
      (or
         (ubg (if C (method "X" C) (getd "X")))
         (quit "Can't unbug" "X") ) ) )

# Tracing
(de traced? ("X" C)
   (setq "X"
      (if C
         (method "X" C)
         (getd "X") ) )
   (and
      (pair "X")
      (pair (cadr "X"))
      (== '$ (caadr "X")) ) )

# Convert ((X Y) A B) --> ((X Y) ($ foo (X Y) A B))
(de trace ("X" C)
   (let *Dbg NIL
      (when (pair "X")
         (setq C (cdr "X")  "X" (car "X")) )
      (if C
         (unless (traced? "X" C)
            (or (method "X" C) (quit "Can't trace" "X"))
            (con @
               (cons
                  (conc
                     (list '$ (cons "X" C) (car @))
                     (cdr @) ) ) ) )
         (unless (traced? "X")
            (and (sym? (getd "X")) (quit "Can't trace" "X"))
            (and (num? (getd "X")) (expr "X"))
            (set "X"
               (list
                  (car (getd "X"))
                  (conc (list '$ "X") (getd "X")) ) ) ) )
      "X" ) )

# Convert ((X Y) ($ foo (X Y) A B)) --> ((X Y) A B)
(de untrace ("X" C)
   (let *Dbg NIL
      (when (pair "X")
         (setq C (cdr "X")  "X" (car "X")) )
      (if C
         (when (traced? "X" C)
            (con
               (method "X" C)
               (cdddr (cadr (method "X" C))) ) )
         (when (traced? "X")
            (let X (set "X" (cddr (cadr (getd "X"))))
               (and
                  (== '@ (++ X))
                  (= 1 (length X))
                  (= 2 (length (car X)))
                  (== 'pass (caar X))
                  (sym? (cdadr X))
                  (subr "X") ) ) ) )
      "X" ) )

(de *NoTrace
   @ @@ @@@
   pp show more led
   what who can dep d e debug u unbug trace untrace )

(de traceAll (Excl)
   (let *Dbg NIL
      (for "X" (all)
         (or
            (memq "X" Excl)
            (memq "X" *NoTrace)
            (= `(char "*") (char "X"))
            (cond
               ((= `(char "+") (char "X"))
                  (mapc trace
                     (extract
                        '(("Y")
                           (and
                              (pair "Y")
                              (fun? (cdr "Y"))
                              (cons (car "Y") "X") ) )
                        (val "X") ) ) )
               ((pair (getd "X"))
                  (trace "X") ) ) ) ) ) )

# Benchmarking
(de bench Prg
   (let U (usec)
      (prog1
         (run Prg 1)
         (prinl
            (format (*/ (- (usec) U) 1000) 3)
            " sec" ) ) ) )

# Backtrace
(de bt (Flg)
   (let (S NIL  *Dbg)
      (for (L (trail T) L)
         (if (pair (car L))
            (push 'S (cons (++ L)))
            (conc
               (car (default S (cons (cons))))
               (cons (cons (++ L) (++ L))) ) )
         (T (== '^ (car L)))
         (T
            (and
               (pair (car L))
               (== 'bt (caar L)) ) ) )
      (for L S
         (let? X (++ L)
            (pretty
               (cons
                  (or
                     (and (sym? (car X)) (car X))
                     (less (has (car X)))
                     (car X) )
                  (less (cdr X)) ) ) )
         (prinl)
         (while L
            (space 3)
            (println (caar L) (less (cdr (++ L)))) )
         (T (and (not Flg) (line)) T) ) ) )

(====)
############ lib/lint.l ############
# *NoLint

(de noLint (X V)
   (if V
      (push1 '*NoLint (cons X V))
      (or (memq X *NoLint) (push '*NoLint X)) ) )

(de global? (S)
   (or
      (memq S '(NIL ^ @ @@ @@@ This T))
      (member (char S) '(`(char '*) `(char '+))) ) )

(de local? (S)
   (or
      (str? S)
      (member (char S) '(`(char '*) `(char '_))) ) )

(de dlsym? (S)
   (and
      (car (setq S (split (chop S) ':)))
      (cadr S)
      (low? (caar S)) ) )

(de lint1 ("X")
   (cond
      ((atom "X")
         (when (sym? "X")
            (cond
               ((memq "X" "*L") (setq "*Use" (delq "X" "*Use")))
               ((local? "X") (lint2 (val "X")))
               (T
                  (or
                     (getd "X")
                     (global? "X")
                     (member (cons "*X" "X") *NoLint)
                     (memq "X" "*Bnd")
                     (push '"*Bnd" "X") ) ) ) ) )
      ((num? (car "X")))
      (T
         (casq (car "X")
            ((: ::))
            (; (lint1 (cadr "X")))
            (quote
               (let F (fun? (cdr "X"))
                  (if (or (and (pair F) (not (fin @))) (== '@ F))
                     (use "*L" (lintFun (cdr "X")))
                     (lint2 (cdr "X")) ) ) )
            ((de dm)
               (let "*X" (cadr "X")
                  (lintFun (cddr "X")) ) )
            (recur
               (let recurse (cdr "X")
                  (lintFun recurse) ) )
            (task
               (lint1 (cadr "X"))
               (let "Y" (cddr "X")
                  (use "*L"
                     (while (num? (car "Y"))
                        (++ "Y") )
                     (while (and (car "Y") (sym? @))
                        (lintVar (++ "Y"))
                        (++ "Y") )
                     (mapc lint1 "Y") ) ) )
            (macro
               (lint2 (cdr "X")) )
            (let?
               (use "*L"
                  (lintVar (cadr "X"))
                  (mapc lint1 (cddr "X")) ) )
            (let
               (use "*L"
                  (if (atom (cadr "X"))
                     (lintVar (cadr "X"))
                     (for (L (cadr "X") L (cddr L))
                        (lintDup (car L)
                           (extract '((X F) (and F X))
                              (cddr L)
                              '(T NIL .) ) )
                        (lintVar (car L))
                        (lint1 (cadr L)) ) )
                  (mapc lint1 (cddr "X")) ) )
            (use
               (use "*L"
                  (if (atom (cadr "X"))
                     (lintVar (cadr "X"))
                     (mapc lintVar (cadr "X")) )
                  (mapc lint1 (cddr "X")) ) )
            (for
               (use "*L"
                  (let "Y" (cadr "X")
                     (cond
                        ((atom "Y")          # (for X (1 2 ..) ..)
                           (lint1 (caddr "X"))
                           (lintVar "Y")
                           (lintLoop (cdddr "X")) )
                        ((atom (cdr "Y"))    # (for (I . X) (1 2 ..) ..)
                           (lintVar (car "Y"))
                           (lint1 (caddr "X"))
                           (lintVar (cdr "Y"))
                           (lintLoop (cdddr "X")) )
                        ((atom (car "Y"))    # (for (X (1 2 ..) ..) ..)
                           (lint1 (cadr "Y"))
                           (lintVar (car "Y"))
                           (mapc lint1 (cddr "Y"))
                           (lintLoop (cddr "X")) )
                        (T                   # (for ((I . L) (1 2 ..) ..) ..)
                           (lintVar (caar "Y"))
                           (lint1 (cadr "Y"))
                           (lintVar (cdar "Y"))
                           (mapc lint1 (cddr "Y"))
                           (lintLoop (cddr "X")) ) ) ) ) )
            ((case casq state)
               (lint1 (cadr "X"))
               (for "X" (cddr "X")
                  (mapc lint1 (cdr "X")) ) )
            ((cond nond)
               (for "X" (cdr "X")
                  (mapc lint1 "X") ) )
            (loop
               (lintLoop (cdr "X")) )
            (do
               (lint1 (cadr "X"))
               (lintLoop (cddr "X")) )
            (=:
               (lint1 (last (cddr "X"))) )
            ((dec inc pop push push1 queue fifo val idx accu)
               (_lintq '(T)) )
            ((cut port)
               (_lintq '(NIL T)) )
            (set
               (_lintq '(T NIL .)) )
            (xchg
               (_lintq '(T T .)) )
            (T
               (cond
                  ((pair (car "X"))
                     (lint1 @)
                     (mapc lint2 (cdr "X")) )
                  ((memq (car "X") "*L")
                     (setq "*Use" (delq (car "X") "*Use"))
                     (mapc lint2 (cdr "X")) )
                  ((fun? (val (car "X")))
                     (if (num? @)
                        (mapc lint1 (cdr "X"))
                        (when (local? (car "X"))
                           (lint2 (val (car "X"))) )
                        (let "Y" (car (getd (++ "X")))
                           (while (and (pair "X") (pair "Y"))
                              (lint1 (++ "X"))
                              (++ "Y") )
                           (if (or (== '@ "Y") (= "Prg" "Y") (= "*Prg" "Y"))
                              (mapc lint1 "X")
                              (lint2 "X") ) ) ) )
                  (T
                     (or
                        (str? (car "X"))
                        (dlsym? (car "X"))
                        (== '@ (car "X"))
                        (memq (car "X") *NoLint)
                        (memq (car "X") "*Def")
                        (push '"*Def" (car "X")) )
                     (mapc lint1 (cdr "X")) ) ) ) ) ) ) )

(de lint2 (X Mark)
   (cond
      ((memq X Mark))
      ((atom X)
         (and (memq X "*L") (setq "*Use" (delq X "*Use"))) )
      (T (lint2 (car X))
         (lint2 (cdr X) (cons X Mark)) ) ) )

(de lintVar (X Flg)
   (cond
      ((or (not (sym? X)) (memq X '(NIL *DB ^ meth quote T)))
         (push '"*Var" X) )
      ((not (global? X))
         (or
            Flg
            (member (cons "*X" X) *NoLint)
            (memq X "*Use")
            (push '"*Use" X) )
         (push '"*L" X) ) ) )

(de lintDup (X Lst)
   (and
      (memq X Lst)
      (not (member (cons "*X" X) *NoLint))
      (push '"*Dup" X) ) )

(de lintLoop ("Lst")
   (for "Y" "Lst"
      (if (and (pair "Y") (or (=T (car "Y")) (not (car "Y"))))
         (mapc lint1 (cdr "Y"))
         (lint1 "Y") ) ) )

(de _lintq (Lst)
   (mapc
      '((X Flg)
         (lint1 (if Flg (strip X) X)) )
      (cdr "X")
      Lst ) )

(de lintFun ("Lst")
   (let "A" (and (pair "Lst") (car "Lst"))
      (while (pair "A")
         (lintDup (car "A") (cdr "A"))
         (lintVar (++ "A") T) )
      (when "A"
         (lintVar "A") )
      (mapc lint1 (cdr "Lst")) ) )

(de lint ("X" "C")
   (let ("*L" NIL  "*Var" NIL  "*Dup" NIL  "*Def" NIL  "*Bnd" NIL  "*Use" NIL)
      (when (pair "X")
         (setq  "C" (cdr "X")  "X" (car "X")) )
      (cond
         ("C"  # Method
            (let "*X" (cons "X" "C")
               (lintFun (method "X" "C")) ) )
         ((pair (val "X"))  # Function
            (let "*X" "X"
               (lintFun (val "X")) ) )
         ((info "X")  # File name
            (let "*X" "X"
               (in "X" (while (read) (lint1 @))) ) )
         (T (quit "Can't lint" "X")) )
      (when (or "*Var" "*Dup" "*Def" "*Bnd" "*Use")
         (make
            # Bad variables
            (and "*Var" (link (cons 'var "*Var")))
            # Duplicate parameters
            (and "*Dup" (link (cons 'dup "*Dup")))
            # Undefined functions
            (and "*Def" (link (cons 'def "*Def")))
            # Unbound variables
            (and "*Bnd" (<> `(char '_) (char "X")) (link (cons 'bnd "*Bnd")))
            # Unused variables
            (and "*Use" (link (cons 'use "*Use"))) ) ) ) )

(de lintAll @
   (let *Dbg NIL
      (make
         (for "X" (all)
            (cond
               ((and (= `(char "+") (char "X")) (pair (val "X")))
                  (for "Y" @
                     (and
                        (pair "Y")
                        (fun? (cdr "Y"))
                        (lint (car "Y") "X")
                        (link (cons (cons (car "Y") "X") @)) ) ) )
               ((and (not (global? "X")) (pair (getd "X")) (lint "X"))
                  (link (cons "X" @)) ) ) )
         (while (args)
            (and (lint (next)) (link (cons (arg) @))) ) ) ) )

(noLint 'pretty 'Z)
(noLint '_pretty 'Z)

# vi:et:ts=3:sw=3
