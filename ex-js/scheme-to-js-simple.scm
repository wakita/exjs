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
  (set! buffer (list (apply string-append (reverse buffer))))
  (bindent (if (null? delta) 0 (car delta)))
  (bformat "~%~v,a" indent-level ""))
(define (bdelete1)
  (if (not (null? buffer))
      (set! buffer (cdr buffer))))
(define (bflush)
  (let ((result (apply string-append (reverse buffer))))
    (breset)
    result))
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

(define unwanted-chars (symbol->list '\x60;\x2E;*))

(define (do-symbol e)
  (let* ((chars (symbol->list e))
         (str (list->string (map (lambda (c)
                                   (if (memq c unwanted-chars) #\_ c)) ;; . ` * を _ にする
                                 chars))))
    (bformat "~a" (string->symbol (pregexp-replace "^(V|P)-" str "")))) ;; シンボルの V- と P- を取り除く
  #t)

(define (do-fargs arg*)
  (bformat "(") (bseparating s2j ", " arg*) (bformat ")"))

(define (do-begin e)
  (for-each (lambda (v) (if (s2j v) (bformat ";")) (bnewline)) e) #f)

(define (do-define e)
  (let ((name (car e))
        (value (cadr e)))
    (if (and (list? value) (equal? (car value) 'lambda))
        (begin (bformat "function ")
               (do-symbol name)
               (bformat " ")
               (do-fargs (cadr value))
               (bformat " ")
               (do-block (cddr value))
               #f)
        (begin (bformat "var ")
               (do-symbol name)
               (if (not (eq? value #\nul))
                   (begin (bformat " = ")
                          (s2j value)))
               #t))))

(define (do-letrec* e)
  (let ((bindings (car e))
        (body (cdr e)))
    (for-each (lambda (b) (if (do-define b) (bformat ";")) (bnewline)) bindings)
    (do-begin body)
    (bdelete1))
  #f)

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
  (s2j (car e))
  (bformat ": ")
  (s2j (cadr e))
  #t)

(define (do-getter e)
  (bformat "get ")
  (s2j (car e))
  (bformat "() ")
  (do-block (cdr e))
  #t)

(define (do-setter e)
  (bformat "set ")
  (s2j (car e))
  (bformat "(~a) " (cadr e))
  (do-block (cddr e))
  #t)

(define (do-new e)
  (let ((constructor (car e))
        (arg* (cdr e)))
    (bformat "(new ")
    (s2j constructor)
    (if (not (null? arg*))
        (begin (bformat " ")
               (do-fargs arg*)))
    (bformat ")"))
  #t)

(define (do-propAccess e)
  (let ((base (car e))
        (name (cadr e)))
    (bformat "(")
    (s2j base)
    (if (string? name)
        (bformat ".~a" name) ;; .のとき
        (begin (bformat "[") ;; []のとき
               (s2j name)
               (bformat "]")))
    (bformat ")"))
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

(define (isblock? e)
  (and (list? e)
       (>= (length e) 2)
       (string? (cadr e))
       (string=? (cadr e) "block")))

(define (do-block e)
  (bformat "{")
  (bnewline 2)
  (do-begin e)
  (bdelete1)
  (bnewline -2)
  (bformat "}")
  #f)

(define (do-if e)
  (let ((e1 (car e))
        (e2 (cadr e))
        (e3 (caddr e)))
    (bformat "if (") (s2j e1) (bformat ") ") ;; condition
    (do-block (if (isblock? e2) (cddr e2) (list e2))) ;; then
    (if (not (eq? e3 #\nul)) ;; else
        (begin
          (bformat " else ")
          (do-block (if (isblock? e3) (cddr e3) (list e3))))))
    #f)

(define (do-dowhile e)
  (bformat "do ")
  (do-block (if (isblock? (cadr e)) (cddadr e) (list (cadr e))))
  (bformat " while (")
  (s2j (car e))
  (bformat ")")
  #f)

(define (do-while e)
  (bformat "while (")
  (s2j (car e))
  (bformat ") ")
  (do-block (if (isblock? (cadr e)) (cddadr e) (list (cadr e))))
  #f)

(define (do-for e)
  (let ((e1 (car e))
        (e2 (cadr e))
        (e3 (caddr e))
        (e4 (cadddr e)))
    (bformat "for (")
    (s2j e1)
    (bformat "; ")
    (if (not (eq? e2 #\nul)) (s2j e2))
    (bformat "; ")
    (if (not (eq? e3 #\nul)) (s2j e3))
    (bformat ") ")
    (do-block (if (isblock? e4) (cddr e4) (list e4))))
  #f)

(define (do-forin e)
  (let ((e1 (car e))
        (e2 (cadr e))
        (e3 (caddr e)))
     (bformat "for (")
     (s2j e1)
     (bformat " in ")
     (s2j e2)
     (bformat ") ")
     (do-block (if (isblock? e3) (cddr e3) (list e3))))
  #f)

(define (do-return e)
  (let ((v (car e)))
    (bformat "return ")
    (if (not (eq? v #\nul)) (s2j v)))
  #t)

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
    (if (not (eq? catch #\nul)) ;; catch (lambda (e) ("JS" "block" body))
        (begin (bformat " catch (")
               (do-symbol (caadr catch))
               (bformat ") ")
               (do-block (cddr (caddr catch)))))
    (if (not (eq? finally #\nul)) ;; finally
        (begin (bformat " finally ")
               (do-block (cddr finally)))))
  #f)

(define (do-function e)
  (let ((name (car e))
        (args (cadr (cadr e)))
        (body (cddr (cadr e))))
    (bformat "(function")
    (if (not (eq? name #\nul)) ;; body = ((letrec* ((name ...) ...) ...))
        (begin (bformat " ")
               (do-symbol (caaadr (car body)))
               (set! body `((letrec* ,(cdadar body) ,@(cddar body))))))
    (bformat " ")
    (do-fargs args)
    (bformat " ")
    (do-block body)
    (bformat ")"))
  #f)
          
(define (do-JS e)
  (let ((type (car e))
        (body (cdr e)))
    (cond ((string=? type "expressions") (do-expressions body))
          ((string=? type "const") (bformat "~a" (car body)) #t)
          ((string=? type "number") (bformat "~a" (car body)) #t)
          ((string=? type "string") (bformat "\"~a\"" ;; double quote
                                             (fold-left
                                              (lambda (str pat ins) (pregexp-replace* pat str ins))
                                              (car body)
                                              '("\\\\" "\"" "\b" "\f" "\n" "\r" "\t" "\v")
                                              '("\\\\\\\\" "\\\\\"" "\\\\b" "\\\\f" "\\\\n" "\\\\r" "\\\\t" "\\\\v"))) #t)
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
             ((define) (do-define (cdr e)))
             ((letrec*) (do-letrec* (cdr e)))
             (else (error 'do-list "Invalid symbol." e))))
          ((equal? head "JS") (do-JS (cdr e)))
          (error 'do-list "Invalid elements." e))))

(define (s2j e)
  (cond ((eq? #\nul e) (error 's2j "Misplaced null character."))
        ((eq? #\@ e) (bdelete1) #f)
        ((boolean? e) (error 's2j "bool: This cannot happen."))
        ((symbol? e) (do-symbol e))
        ((number? e) (error 's2j "num: This cannot happen."))
        ((char? e) (error 's2j "string: This cannot happen."))
        ((list? e) (do-list e))
        ((or (vector? e) (port? e) (procedure? e))
         (error 's2j "Invalid elements in the Scheme program (port or procedure)." e))))

(define (scheme-to-javascript scm)
  (breset)
  (s2j scm)
  (bflush))