(define global-foundry "")
(define global-family "")
(define global-weight "")
(define global-slant "")
(define global-set-width "")
(define global-spacing "")

(define (setglobals foundry family weight slant set-width spacing)
(set! global-foundry foundry)
(set! global-family family)
(set! global-weight weight)
(set! global-slant slant)
(set! global-set-width set-width)
(set! global-spacing spacing)
1)

(define (test_side file text)
(script_fu_mmrg_sideicon text 18 "adobe" "helvetica" "*"
"r" "normal" "*" FALSE  file '(255 255 0) '(0 35 105) TRUE)
)

(define (script_fu_mmrg_sideicon
	 text text-size foundry family weight slant set-width spacing
         transparent filename foreground-colour background-colour interactive
	 text-outline)

(define (drawpart text img background text-size offset)
  (gimp-text img background 0 offset text 0 TRUE text-size PIXELS
             global-foundry global-family global-weight global-slant
             global-set-width global-spacing))

(define (drawbits l img background text-size offset)
(prin1 "drawbits:") (print l)
  (if (null? l)
    '()
    (cons
    (drawpart (car l) img background text-size offset)
    (drawbits (cdr l) img background text-size (+ offset 10))
    )))

(define (map3 f a b c)
  (if (null? a)
    '()
    (cons
      (f (car a) (car b) (car c))
      (map3 f (cdr a) (cdr b) (cdr c)))))

(define (maxl l result)
  (if (null? l) result
    (maxl (cdr l) (if (> (car l) result) (car l) result))))

(define (make-heights n l d)
  (if (= n 0 ) l
    (make-heights (- n 1) (cons (* d (- n 1)) l) d)))


(define (drawtext text img background text-size)
(prin1 "drawtext:")
(print text)
  (let* (
    (newstuff (drawbits (strbreakup text "\n") img -1 text-size 0))
    (widths (map (lambda(x)(car (gimp-drawable-width (car x)))) newstuff))
    (heights (make-heights (length newstuff) '() text-size))
    (maxwidth (maxl widths 0))
    )
(print newstuff) (print widths) (print heights) (print maxwidth)
  (map3 (lambda(x y z)
          (gimp-layer-set-offsets (car x) (/ (- maxwidth y) 2) z)
        )
        newstuff widths heights)
  (print widths)
(if (> (length widths) 1)
  (gimp-image-merge-visible-layers img 0)
  (caar newstuff)
)))

(define (findwidths text img background text-size)
(map (lambda(x)
        (let* ((textl (car (drawpart x img -1 text-size 0) ))
               (result (cons x (car (gimp-drawable-width textl)))))
       ;(gimp-layer-set-visible textl 0)
       (gimp-image-remove-layer img textl)
(print result)
        result
        )
      )
     (strbreakup text " ")
)
)

(define (widthspace img text-size)
(let* ((textl (car (drawpart " " img -1 text-size 0) ))
               (result (car (gimp-drawable-width textl))))
       (gimp-image-remove-layer img textl)
		 (prin1 result)
        result))


(define (check-max in max)
  (if (> (cdr (car in)) max) (= 1 0) (check-max (cdr in) max))
)

(define (blah in out count ideal max lastnewline space)
(prin1 "blah:") (prin1 in) (prin1 ":") (prin1 out) (prin1 ":") (prin1 count)
(prin1 ":") (prin1 max) (prin1 ":") (print space)
  (let* (
     (newwidth (+ count (if (= lastnewline 1) 0 space)(cdr (car in))))
     )
  (if (null? in)
    out
    (if (< newwidth max)
      (blah (cdr in)
            (string-append out (if (= lastnewline 1) "" " ") (caar in))
            newwidth
            ideal max 0 space)
      (if (= 1 lastnewline)
        (blah (cdr in)
              (string-append out (caar in))
              (cdr (car in))
              ideal max 0 space)
        (blah in (string-append out "\n") 0 ideal max 1 space)
      )))))

(define (splitit text max-width max-height img background text-size
         width height)
   (let* (
      (w (findwidths text img background text-size))
      (half-width (/ width 2))
      (result (blah w "" 0 half-width max-width 1 text-size))
      (textl (car (drawtext result img background text-size) ))
      (newwidth  (car (gimp-drawable-width textl)))
      (newheight (car (gimp-drawable-height textl))))
(print result )
(prin1 newwidth) (prin1 ":") (prin1 max-width) (prin1 ":") (prin1
newheight)
(prin1 ":") (print max-height)

    ;(cond
    ;  ((> newwidth max-width)
    ;     (gimp-image-remove-layer img textl)
    ;     (formatit text max-width max-height img background (- text-size 2)))
    ;  ((> newheight max-height)
    ;     (gimp-image-remove-layer img textl)
    ;     (formatit text max-width max-height img background (/ text-size 2)))
    ;  (t textl))
    textl
   )
)

(define (formatit text max-width max-height img background text-size)
(print "formatit")
  (let*
     ((textl (car (drawpart text img -1 text-size 0) ))
     (width  (car (gimp-drawable-width textl)))
     (height (car (gimp-drawable-height textl))))
(print width) (print height) (print max-width) (print max-height) (print img)
    (cond
      ((> width max-width)
         (gimp-image-remove-layer img textl)
         (splitit text max-width max-height img
                  background text-size width height))
      ((> height max-height) )
      (t  textl )
      )
    )
  )

  (let* (
     (a (setglobals foundry family weight slant set-width spacing))
     (old-bg-color (car (gimp-palette-get-background)))
	 (img (car (gimp-image-new 10 10 RGB)))
	 (max-width 110)
	 (max-height 120)
     (dummy (gimp-palette-set-foreground foreground-colour))
	 (background (car (gimp-layer-new img max-width max-height RGBA_IMAGE "Background" 100 NORMAL)))
     (textl (formatit text (- max-width 8 ) max-height img background text-size))
     (width (car (gimp-drawable-width textl)))
     (height (car (gimp-drawable-height textl)))
     )
    (gimp-image-disable-undo img)
    (gimp-image-resize img max-width (+ 5 height) 0 0)
    (gimp-image-add-layer img background 1)
    (gimp-palette-set-background background-colour)
    (gimp-edit-fill img background)
    (gimp-bucket-fill img background BG-BUCKET-FILL NORMAL 100 0 FALSE 0 0)
    (gimp-layer-set-offsets textl (/ (- max-width width) 2) 3)
    (gimp-selection-none img)
    (gimp-image-set-active-layer img background)
    (set! upper-layer (car (gimp-layer-copy textl 0)))
    (gimp-layer-set-visible upper-layer 1)
    (gimp-image-add-layer img upper-layer 1)
    (gimp-layer-resize upper-layer (+ 6 width) (+ 6 height) 3 3)
    (gimp-image-set-active-layer img upper-layer)
    (gimp-selection-layer-alpha img upper-layer)
    (gimp-selection-grow img 1)
    (gimp-palette-set-foreground text-outline)
    (gimp-edit-fill img background)
    (gimp-bucket-fill img upper-layer FG-BUCKET-FILL NORMAL 100 0 FALSE 0 0)
    (if (= transparent FALSE)
      (gimp-image-flatten img))
    (gimp-palette-set-background old-bg-color)
    (gimp-convert-indexed img 1 256)
    (gimp-file-save 1 img background filename filename)
    (if (= interactive TRUE)
      (begin (gimp-display-new img) (gimp-image-enable-undo img)) (gimp-image-delete img))
))



(script-fu-register "script_fu_mmrg_sideicon"
		    "<Toolbox>/Xtns/Script-Fu/MMRG Sidebar"
		    "MMRG Web Page Sidebar"
		    "Danius Michaelides"
		    "Danius Michaelides"
		    "March 1998"
		    ""
		    SF-VALUE  "Text"                   "\"ECS Research Groups\""
		    SF-VALUE  "Text size"              "16"
		    SF-VALUE  "Foundry"                "\"adobe\""
		    SF-VALUE  "Family"                 "\"helvetica\""
		    SF-VALUE  "Weight"                 "\"bold\""
		    SF-VALUE  "Slant"                  "\"r\""
		    SF-VALUE  "Set width"              "\"normal\""
		    SF-VALUE  "Spacing"                "\"\*\""
		    SF-TOGGLE "Transparent background" FALSE
		    SF-VALUE  "Filename"	       "\"heading.gif\""
            SF-COLOR  "Foreground" '(255 255 0)
            SF-COLOR  "Background" '(0 35 105)
		    SF-TOGGLE "Display" TRUE
)

