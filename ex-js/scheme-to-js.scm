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

(define functions (make-eq-hashtable)) ;; lambda 式を保存するハッシュ表

(define (symbol->list sym)
  (string->list (symbol->string sym)))

(define unwanted-chars (symbol->list '\x60;\x2E;*))

(define (do-symbol e)
  (let* ((chars (symbol->list e))
         (str (list->string (map (lambda (c)
                                   (if (memq c unwanted-chars) #\_ c)) ;; . ` * を _ にする
                                 chars))))
    (bformat "~a" (string->symbol (pregexp-replace "^(V|LK)-" str "")))) ;; 変数名の V- と LK- を取り除く
  #t)

(define (do-fargs arg*)
  (bformat "(") (bseparating s2j ", " arg*) (bformat ")"))

(define (do-begin e)
  (for-each (lambda (v) (if (s2j v) (bformat ";")) (bnewline)) e) #f)

(define (do-expressions e)
  (bformat "(") (bseparating s2j ", " e) (bformat ")") #t)

(define (do-array e)
  (bformat "[ ") (bseparating s2j ", " e) (bformat " ]") #t)

(define (do-object e)
  (bformat "{ ")
  (bseparating s2j ", " e)
  (bformat " }")
  #t)

(define (do-propAssign e)
  (bformat "~a: " (car e))
  (s2j (cadr e))
  #t)

(define (do-getter e)
  (bformat "get ~a() " (car e))
  (do-block (cdr e))
  #t)

(define (do-setter e)
  (bformat "set ~a(~a) " (car e) (cadr e))
  (do-block (cddr e))
  #t)

(define (do-new e)
  (let ((constructor (car e))
        (arg* (cdr e)))
    (bformat "new ")
    (s2j counstructor)
    (if (not (null? arg*))
        (begin (bformat " ")
               (do-fargs arg*))))
  #t)

(define (do-propAccess e)
  (let ((base (car e))
        (name (cadr e)))
    (s2j base)
    (if (string? name)
        (bformat ".~a" name) ;; .のとき
        (begin (bformat "[") ;; []のとき
               (s2j name)
               (bformat "]"))))
  #t)

(define (do-funcCall e)
  (let ((name (car e))
        (arg* (cdr e)))
    (bformat "(")
    (s2j name)
    (bformat " ")
    (do-fargs arg*)
    (bformat ")"))
  #t)

(define (do-postfix e)
  (let ((op (car e))
        (e1 (cadr e)))
    (bformat "(")
    (s2j e1)
    (bformat " ~a)" op))
  #t)

(define (do-unary e)
  (let ((op (car e))
        (e1 (cadr e)))
    (bformat "(~a " op)
    (s2j e1)
    (bformat ")"))
  #t)

(define (do-binary e)
  (let ((op (car e))
        (e1 (cadr e))
        (e2 (caddr e)))
    (bformat "(")
    (s2j e1) (bformat " ~a " op) (s2j e2)
    (bformat ")"))
  #t)

(define (do-assignment e)
  (let ((op (car e))
        (e1 (cadr e))
        (e2 (caddr e)))
    (bformat "(")
    (s2j e1) (bformat " ~a " op) (s2j e2)
    (bformat ")"))
  #t)

(define (do-conditional e)
  (let ((e1 (car e))
        (e2 (cadr e))
        (e3 (caddr e)))
    (bformat "((") (s2j e1)
    (bformat ") ? (") (s2j e2)
    (bformat ") : (") (s2j e3)
    (bformat "))"))
  #t)

(define (do-statement e)
  (if (and (list? e) (>= (length e) 2) (string=? (cadr e) "block"))
      (begin
        (do-block (cddr e))
        #t)
      (begin
        (if (s2j e) (bformat ";"))
        #f)))

(define (do-block e)
  (bformat "{")
  (bnewline 2)
  (do-begin e)
  (bdelete1)
  (bnewline -2)
  (bformat "}")
  #f)

(define (do-variable e)
  (bformat "var ")
  (bseparating (lambda (s)
                 (let ((name (car s))
                       (value (cadr s)))
                   (do-symbol name)
                   (if (not (eq? value #\nul))
                       (begin
                         (bformat " = ")
                         (s2j value)))))
               ", "
               e)
  #t)

(define (do-if e)
  (let ((e1 (car e))
        (e2 (cadr e))
        (e3 (caddr e))
        (block #t))
    (bformat "if (") (s2j e1) (bformat ") ") ;; condition
    (set! block (do-statement e2)) ;; then
    (if (not (eq? e3 #\nul)) ;; else
        (begin
          (if block (bformat " ") (bformat "~%"))
          (bformat "else ")
          (do-statement e3))))
  #f)

(define (do-dowhile e)
  (let ((block #t))
    (bformat "do ")
    (set! block (do-statement (cadr e)))
    (if block (bformat " ") (bformat "~%"))
    (bformat "while (")
    (s2j (car e))
    (bformat ")"))
  #f)

(define (do-while e)
  (bformat "while (")
  (s2j (car e))
  (bformat ") ")
  (do-statement (cadr e))
  #f)

(define (do-for e)
  (let ((e1 (car e))
        (e2 (cadr e))
        (e3 (caddr e))
        (e4 (cadddr e)))
    (bformat "for (")
    (if (and (list? e1) (list? (car e1)))
        (do-variable e1)
        (s2j e1))
    (bformat "; ")
    (if (not (eq? e2 #\nul)) (s2j e2))
    (bformat "; ")
    (if (not (eq? e3 #\nul)) (s2j e3))
    (bformat ") ")
    (do-statement e4))
  #f)

(define (do-forin e)
  (let ((e1 (car e))
        (e2 (cadr e))
        (e3 (caddr e)))
     (bformat "for (")
     (if (and (list? e1) (symbol? (car e1)) (pregexp-match "^V-" (symbol->string (car e1))))
         (do-variable (list e1))
         (s2j e1))
     (bformat " in ")
     (s2j e2)
     (bformat ") ")
     (do-statement e3))
  #f)

(define (do-return e)
  (bformat "return ")
  (s2j (car e))
  #t)

(define (do-with e)
  (bformat "with (")
  (s2j (car e))
  (bformat ") ")
  (do-statement (cadr e))
  #f)

(define (do-switch e)
  (bformat "switch (")
  (s2j (car e))
  (bformat ") {")
  (bnewline 2)
  (for-each s2j (cdr e))
  (bdelete1)
  (bnewline -2)
  (bformat "}")
  #f)

(define (do-case e)
  (bformat "case ")
  (s2j (car e))
  (bformat ":")
  (bnewline 2)
  (do-begin (cdr e))
  (bdelete1)
  (bnewline -2)
  #f)

(define (do-default e)
  (bformat "default: ")
  (bnewline 2)
  (do-begin e)
  (bdelete1)
  (bnewline -2)
  #f)

(define (do-try e)
  (let ((block (car e))
        (catch (cadr e))
        (finally (caddr e)))
    (bformat "try ")
    (do-block (cddr block)) ;; block
    (if (not (eq? catch #\nul)) ;; catch
        (begin (bformat " catch (")
               (do-symbol (car catch))
               (bformat ") ")
               (do-block (cddr (cadr catch)))))
    (if (not (eq? finally #\nul)) ;; finally
        (begin (bformat " finally ")
               (do-block (cddr finally)))))
  #f)

(define (do-function e)
  (let ((name (car e))
        (function (cadr e)))
    (if (symbol? function)
        (set! function (hashtable-ref functions function #\nul)))
    (if (not (eq? function #\nul))
        (begin
          (bformat "function")
          (if (not (eq? name #\nul)) (begin (bformat " ") (do-symbol name)))
          (bformat " ")
          (do-fargs (cadr function))
          (bformat " ")
          (let ((body (cddr function)))
            (if (and (list? body) (= (length body) 1) (list? (car body)) (eq? (caar body) 'letrec*)) ;; letrec*のとき
                (set! body (cddar body)))
            (do-block body)))))
  #f)
          
(define (do-JS e)
  (let ((type (car e))
        (body (cdr e)))
    (cond ((string=? type "expressions") (do-expressions body))
          ((string=? type "const") (bformat "~a" (car body)) #t)
          ((string=? type "number") (bformat "~a" (car body)) #t)
          ((string=? type "string") (let ((value (car body)))
                                 (if (pregexp-match "\"" value)
                                     (bformat "'~a'" value)      ;; single quote
                                     (bformat "\"~a\"" value))) #t) ;; double quote
          ((string=? type "array") (do-array body))
          ((string=? type "object") (do-object body))
          ((string=? type "propAssign") (do-propAssign body))
          ((string=? type "getter") (do-getter body))
          ((string=? type "setter") (do-setter body))
          ((string=? type "new") (do-new body))
          ((string=? type "propAccess") (do-propAccess body))
          ((string=? type "funcCall") (do-funcCall body))
          ((string=? type "postfix") (do-postfix body))
          ((string=? type "unary") (do-unary body))
          ((string=? type "binary") (do-binary body))
          ((string=? type "assignment") (do-assignment body))
          ((string=? type "conditional") (do-conditional body))
          ((string=? type "block") (do-block body))
          ((string=? type "variable") (do-variable body))
          ((string=? type "empty") #t) ;; (bformat ";")
          ((string=? type "if") (do-if body))
          ((string=? type "dowhile") (do-dowhile body))
          ((string=? type "while") (do-while body))
          ((string=? type "for") (do-for body))
          ((string=? type "forin") (do-forin body))
          ((string=? type "continue") (let ((label (car body)))
                                   (bformat "continue")
                                   (if (not (eq? label #\nul)) (bformat " ~a" label))) #t)
          ((string=? type "break") (let ((label (car body)))
                                (bformat "break")
                                (if (not (eq? label #\nul)) (bformat " ~a" label))) #t)
          ((string=? type "return") (do-return body))
          ((string=? type "with") (do-with body))
          ((string=? type "switch") (do-switch body))
          ((string=? type "case") (do-case body))
          ((string=? type "default") (do-default body))
          ((string=? type "labelled") (bformat "~a: " (car body)) (do-statement (cadr body)) #f)
          ((string=? type "throw") (bformat "throw ") (s2j (car body)) #t)
          ((string=? type "try") (do-try body))
          ((string=? type "debugger") (bformat "debugger") #t)
          ((string=? type "function") (do-function body))
          (error 'do-JS "Invalid expression" e))))

(define (do-list e)
  (let ((head (car e)))
    (cond ((symbol? head)
           (case head
             ((begin) (do-begin (cdr e)))
             ((define) (if (not (null? (caddr e))) (hashtable-set! functions (cadr e) (caddr e)))))
           #f)
          ((string=? head "JS") (do-JS (cdr e)))
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

(define (scheme-to-javascript scm)
  (breset)
  (s2j scm)
  (bflush))