;*=====================================================================*/
;*    .../project/bigloo/bigloo/comptime/Integrate/volatile.scm        */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Sat Jun 12 08:55:10 2021                          */
;*    Last change :  Sat Jun 12 09:34:56 2021 (serrano)                */
;*    Copyright   :  2021 Manuel Serrano                               */
;*    -------------------------------------------------------------    */
;*    Flag as "volatile" local variables that traverses a set-exit     */
;*    node. This is used only when  *local-exit?* is true.             */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module integrate_volatile
   (include "Tools/trace.sch"
	    "Tools/verbose.sch")
   (import  type_type
	    engine_param
	    ast_var
	    ast_node
	    ast_walk
	    tools_shape
	    tools_speek)
   (export  (volatile!::global ::global)))

;*---------------------------------------------------------------------*/
;*    volatile! ...                                                    */
;*---------------------------------------------------------------------*/
(define (volatile! global)
   (with-access::global global (value id)
      (with-access::sfun value (body)
	 (volatile body '())))
   global)

;*---------------------------------------------------------------------*/
;*    volatile ::node ...                                              */
;*---------------------------------------------------------------------*/
(define-walk-method (volatile node::node env)
   (call-default-walker))

;*---------------------------------------------------------------------*/
;*    volatile ::let-var ...                                           */
;*---------------------------------------------------------------------*/
(define-walk-method (volatile node::let-var env)
   (with-access::let-var node (bindings body)
      (for-each (lambda (b)
		   (volatile (cdr b) env))
	 bindings)
      (volatile body (append bindings env))))

;*---------------------------------------------------------------------*/
;*    volatile ::let-fun ...                                           */
;*---------------------------------------------------------------------*/
(define-walk-method (volatile node::let-fun env)
   (with-access::let-fun node (locals body)
      (for-each (lambda (l)
		   (with-access::local l (value)
		      (with-access::sfun value (body)
			 (volatile body env))))
	 locals)
      (volatile body env)))

;*---------------------------------------------------------------------*/
;*    volatile ::set-ex-it ...                                         */
;*---------------------------------------------------------------------*/
(define-walk-method (volatile node::set-ex-it env)
   (for-each (lambda (l)
		(with-access::local (car l) (volatile id)
		   (set! volatile #t)))
      env)
   (with-access::set-ex-it node (body)
      (volatile body env)))
      
