(define (dolots-heading f)
  (let* ((file (fopen f "r"))
         (l (read file))
        )
  (mapcar (lambda(x)
    (script_fu_mmrg_heading (cadr x) 30 "bitstream" "gill" "bold" "r"
                            "normal" "m" FALSE (car x) FALSE))
    l)
  )
)

(script-fu-register "dolots-heading"
            "<Toolbox>/Xtns/Script-Fu/Do lots of Headings"
            "MMRG Web Page Heading Thing"
            "Danius"
            "Danius"
            "March 1998"
            ""
            SF-VALUE "Filename" "\"blah.head\""
)

(define (dolots-sideicons f)
  (let* ((file (fopen f "r"))
         (l (read file))
        )
  (mapcar (lambda(x)
    (script_fu_mmrg_sideicon (cadr x) 16 "adobe" "helvetica" "bold" "r"
                             "normal" "*" FALSE (car x) (caddr x)
                             (caddr (cdr x)) FALSE (caddr (cddr x))))
    l)
  )
)

(script-fu-register "dolots-sideicons"
            "<Toolbox>/Xtns/Script-Fu/Do lots of Sideicons"
            "MMRG Web Page Heading Thing"
            "Danius"
            "Danius"
            "March 1998"
            ""
            SF-VALUE "Filename" "\"blah.side\""
)

(define (do-one)
	(script_fu_mmrg_sideicon
		"Test"
		16
		"adobe"
		"helvetica"
		"bold"
		"r"
		"normal"
		"*"
		FALSE
		"temp.gif"
		'(255 255 255)
		'(255 255 0)
		FALSE
		'(0 0 255)
	)
)

;(define (reload)
;(load "do.lots.scm")
;)
;
;(define (test)
;(dolots "blah")
;)
;
;
;(script_fu_mmrg_heading
;         text text-size foundry family weight slant set-width spacing
;         transparent filename)
;
;;;;;;;
