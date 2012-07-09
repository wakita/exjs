(import (slib format))
(import (pregexp))

(define indent-level 0)
(define buffer '())
(define (bformat . arg*)
  (let ((output (apply format (cons #f arg*))))
    (set! buffer (cons output buffer))))
(define (bindent delta)
  (set! indent-level (+ indent-level delta)))
(define (bnewline . delta)
  (bindent (if (null? delta) 0 (car delta)))
  (bformat "~%~v,a" indent-level ""))
(define (bdelete1)
  (set! buffer (cdr buffer)))
(define (bflush)
  (let ((result (apply string-append (reverse buffer))))
    (breset)
    result))
(define (bprint . port)
  (if (null? port)
      (display (buffer-flush))
      (display (buffer-flush) (car port))))
(define (bseparating f sep l)
  (fold-left (lambda (sep? e)
           (if sep? (bformat "~a" sep))
           (f e)
           #t)
         #f l))
(define (breset)
  (set! buffer '())
  (set! indent-level 0))

(define (symbol->list sym)
  (string->list (symbol->string sym)))
;;(define (list->symbol l)
;;  (string->symbol (list->string l)))

(define unwanted-chars (symbol->list '\x60;\x2E;*))

(define (do-symbol e)
  (let* ((chars (symbol->list e))
         (str (list->string (map (lambda (c)
                                   (if (memq c unwanted-chars) #\_ c)) ;; . ` * を _ にする
                                 chars))))
    (bformat "~a" (string->symbol (pregexp-replace "^(V|LK)-" str ""))))) ;; 変数名の V- と LK- を取り除く

(define (do-fargs arg*)
  (bformat " (") (bseparating s2j ", " arg*) (bformat ") "))

(define (do-begin e)
  (for-each (lambda (v) (s2j v) (bformat ";") (bnewline)) e))

(define (do-define e)
  (let ((name (car e))
        (body (cadr e)))
    (bformat "var ") (do-symbol name) (bformat " = ")
    (s2j body) ; (do-lambda (cdr body))
;;    (bformat ";")
))

(define (do-lambda e)
  (let ((arg* (car e))
        (body (cdr e)))
    (bformat "function")
    (do-fargs arg*)
    (bformat "{") ;; (do-block body)
    (bnewline 2)
    (do-begin body)
    (bdelete1)
    (bnewline -2)
    (bformat "}")))

(define (do-expressions e)
  (bformat "(") (bseparating s2j ", " e) (bformat ")"))

(define (do-array e)
  (bformat "[ ") (bseparating s2j ", " e) (bformat " ]"))

(define (do-object e)
  '())

(define (do-propAssign e)
  '())

(define (do-getter e)
  '())

(define (do-setter e)
  '())

(define (do-new e)
  '())

(define (do-propAccess e)
  '())

(define (do-funcCall e)
  (let ((name (car e))
        (arg* (cdr e)))
    (s2j name)
    (do-fargs arg*)
;;    (bformat ";")
))

(define (do-postfix e)
  (let ((op (car e))
        (e1 (cadr e)))
    (bformat "(")
    (s2j e1)
    (bformat " ~a)" op)))

(define (do-unary e)
  (let ((op (car e))
        (e1 (cadr e)))
    (bformat "(~a " op)
    (s2j e1)
    (bformat ")")))

(define (do-binary e)
  (let ((op (car e))
        (e1 (cadr e))
        (e2 (caddr e)))
    (bformat "(")
    (s2j e1) (bformat " ~a " op) (s2j e2)
    (bformat ")")))

(define (do-assignment e)
  (let ((op (car e))
        (e1 (cadr e))
        (e2 (caddr e)))
    (bformat "(")
    (s2j e1) (bformat " ~a " op) (s2j e2)
    (bformat ")")))

(define (do-conditional e)
  (let ((e1 (car e))
        (e2 (cadr e))
        (e3 (caddr e)))
    (bformat "((") (s2j e1)
    (bformat ") ? (") (s2j e2)
    (bformat ") : (") (s2j e3)
    (bformat "))")))

(define (do-block e)
  (bformat "{")
  (bnewline 2)
  (do-begin e)
  (bdelete1)
  (bnewline -2)
  (bformat "}"))

(define (do-variable e)
  (bformat "var ")
  (bseparating (lambda (s)
                 (let ((name (car s))
                       (value (cadr s)))
                   (do-symbol name)
                   (if (not (eq? value #\nul))
                       (begin
                         (bformat " = ")
                         (s2j value))
                       '())))
               ", "
               e)
;;  (bformat ";")
)

(define (do-if e)
  (letrec ((e1 (car e))
           (e2 (cadr e))
           (e3 (caddr e))
           (block #t)
           (do-stmt (lambda (s)
                      (if (and (list? s) (>= (length s) 2) (eq? (cadr s) "block"))
                          (do-block (cddr s))
                          (begin
                            (set! block #f)
                            (bnewline 2) (s2j s) (bindent -2))))))
    (bformat "if (") (s2j e1) (bformat ") ")
    (do-stmt e2)
    (if (not (eq? e3 #\nul))
        (begin
          (if block (bformat " ") (bnewline))
          (bformat "else ")
          (do-stmt e3)))))

(define (do-dowhile e)
  '())

(define (do-while e)
  '())

(define (do-for e)
  '())

(define (do-forin e)
  '())

(define (do-return e)
  (bformat "return ")
  (s2j (car e))
;;  (bformat ";")
)

(define (do-with e)
  '())

(define (do-switch e)
  '())

(define (do-case e)
  '())

(define (do-default e)
  '())

(define (do-labelled e)
  '())

(define (do-throw e)
  '())

(define (do-try e)
  '())

(define (do-catch e)
  '())

(define (do-finaly e)
  '())

(define (do-debugger e)
  '())

(define (do-function e)
  '())

(define (do-JS e)
  (let ((type (car e))
        (body (cdr e)))
    (cond ;((eq? type "brace")
          ; (bformat "{")
          ; (s2j body)
          ; (bformat "}"))
          ;((eq? type "paren")
          ; (bformat "(")
          ; (s2j body)
          ; (bformat ")"))
          ;((eq? type "bracket")
          ; (bformat "[")
          ; (s2j body)
          ; (bformat "]"))
          ((eq? type "expressions") (do-expressions body))
          ((eq? type "const") (bformat "~a" (car body)))
          ((eq? type "number") (bformat "~a" (car body)))
          ((eq? type "array") (do-array body))
          ((eq? type "object") (do-object body))
          ((eq? type "propAssign") (do-propAssign body))
          ((eq? type "getter") (do-getter body))
          ((eq? type "setter") (do-setter body))
          ((eq? type "new") (do-new body))
          ((eq? type "propAccess") (do-propAccess body))
          ((eq? type "funcCall") (do-funcCall body))
          ((eq? type "postfix") (do-postfix body))
          ((eq? type "unary") (do-unary body))
          ((eq? type "binary") (do-binary body))
          ((eq? type "assignment") (do-assignment body))
          ((eq? type "conditional") (do-conditional body))
          ((eq? type "block") (do-block body))
          ((eq? type "variable") (do-variable body))
          ((eq? type "empty") (bformat ";"))
          ((eq? type "if") (do-if body))
          ((eq? type "dowhile") (do-dowhile body))
          ((eq? type "while") (do-while body))
          ((eq? type "for") (do-for body))
          ((eq? type "forin") (do-forin body))
          ((eq? type "return") (do-return body))
          ((eq? type "with") (do-with body))
          ((eq? type "switch") (do-switch body))
          ((eq? type "case") (do-case body))
          ((eq? type "default") (do-default body))
          ((eq? type "labelled") (do-labelled body))
          ((eq? type "throw") (do-throw body))
          ((eq? type "try") (do-try body))
          ((eq? type "catch") (do-catch body))
          ((eq? type "finaly") (do-finaly body))
          ((eq? type "debugger") (do-debugger body))
          ((eq? type "function") (do-function body))
          (error 'do-JS "Invalid expression" e))))

(define (do-list e)
  (let ((head (car e)))
    (cond ((symbol? head)
           (cond ((eq? head 'begin) (do-begin (cdr e)))
                 ((eq? head 'define) (do-define (cdr e)))
                 ((eq? head 'lambda) (do-lambda (cdr e)))))
          ((eq? head "JS") (do-JS (cdr e)))
          (error 'do-list "Invalid elements." e))))

(define (s2j e)
  (cond ((eq? #\nul e) (display "null"))
        ((boolean? e) (error 's2j "bool: This cannot happen"))
        ((symbol? e) (do-symbol e))
        ((number? e) (error 's2j "num: This cannot happen"))
        ((char? e) (error 's2j "string: This cannot happen"))
        ((list? e) (do-list e))
        ((or (vector? e) (port? e) (procedure? e))
         (error 's2j "Invalid elements in the Scheme program (port or procedure)." e))))

;; (define (scheme-to-javascript scm js-file-path)
;;   (let ((out (transcoded-port (open-file-output-port
;;                                js-file-path
;;                                (file-options no-fail))
;;                               (make-transcoder utf-8-codec))))
;;     (put-string out (s2j scm))))

(define (scheme-to-javascript scm)
  (breset)
  (s2j scm)
  (bflush))