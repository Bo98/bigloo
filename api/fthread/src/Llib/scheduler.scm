;*=====================================================================*/
;*    .../prgm/project/bigloo/api/fthread/src/Llib/scheduler.scm       */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Thu May 29 06:40:08 2003                          */
;*    Last change :  Fri Jun 19 16:41:08 2009 (serrano)                */
;*    Copyright   :  2003-09 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    The FairThreads scheduler                                        */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __ft_scheduler
   
   (library pthread)

   (import  __ft_types
	    __ft_%types
	    __ft_%scheduler
	    __ft_%env
	    __ft_%thread
	    __ft_thread
	    __ft_signal
	    __ft_%pthread)
   
   (export  (current-scheduler)
	    (default-scheduler . scdl)
	    (make-scheduler::scheduler . env)
	    (with-scheduler ::scheduler ::procedure)
	    (scheduler-react! . scdl)
	    (scheduler-start! . args)
	    (scheduler-terminate! . ::obj)
	    (scheduler-instant::int . ::obj)
	    
	    (broadcast! ::obj . val)
	    (scheduler-broadcast! ::scheduler ::obj . val)))
	   
;*---------------------------------------------------------------------*/
;*    *current-scheduler* & *default-scheduler* ...                    */
;*---------------------------------------------------------------------*/
(define *current-scheduler* #f)
(define *default-scheduler* #f)

;*---------------------------------------------------------------------*/
;*    current-scheduler ...                                            */
;*---------------------------------------------------------------------*/
(define (current-scheduler) *current-scheduler*)

;*---------------------------------------------------------------------*/
;*    default-scheduler ...                                            */
;*---------------------------------------------------------------------*/
(define (default-scheduler . scdl)
   (cond
      ((null? scdl)
       *default-scheduler*)
      ((scheduler? (car scdl))
       (set! *default-scheduler* (car scdl))
       (car scdl))
      (else
       (error "default-scheduler" "Illegal scheduler" (car scdl)))))

;*---------------------------------------------------------------------*/
;*    with-scheduler ...                                               */
;*---------------------------------------------------------------------*/
(define (with-scheduler s thunk)
   (let ((old (default-scheduler)))
      (unwind-protect
	 (begin
	    (default-scheduler s)
	    (thunk))
	 (default-scheduler old))))

;*---------------------------------------------------------------------*/
;*    with-current-scheduler ...                                       */
;*---------------------------------------------------------------------*/
(define (with-current-scheduler s proc)
   (let ((cs (current-scheduler)))
      (set! *current-scheduler* s)
      (let ((r (proc s)))
	 (set! *current-scheduler* cs)
	 r)))
   
;*---------------------------------------------------------------------*/
;*    make-scheduler ...                                               */
;*---------------------------------------------------------------------*/
(define (make-scheduler . envs)
   (let ((id (gensym 'scheduler)))
      (letrec ((s (instantiate::%scheduler
		     (body (lambda () (schedule s)))
		     (name id)
		     (env+ (append envs (list (instantiate::%env)))))))
	 ;; create the native thread
	 (with-access::%scheduler s (%builtin)
	    (set! %builtin (%fscheduler-new s)))
	 ;; if there is no default scheduler, store that one
	 (if (not (default-scheduler)) (default-scheduler s))
	 ;; start the native thread (that will block instantly)
	 (thread-start! (fthread-%builtin s))
	 ;; return the newly allocated scheduler
	 s)))

;*---------------------------------------------------------------------*/
;*    scheduler-state ...                                              */
;*---------------------------------------------------------------------*/
(define (scheduler-state s::scheduler)
   (with-access::%scheduler s (%state
			       %live-thread-number
			       %threads-ready
			       tostart
			       toterminate
			       tosuspend/resume)
      (cond
	 ((=fx %live-thread-number 0)
	  'done)
	 ((or %threads-ready
	      (pair? tostart)
	      (pair? toterminate)
	      (pair? tosuspend/resume))
	  ;; some threads have to be started or stopped, we are ready to
	  'ready)
	 ((%thread-is-dead s)
	  'dead)
	 (else
	  'await))))

;*---------------------------------------------------------------------*/
;*    schedule ...                                                     */
;*    -------------------------------------------------------------    */
;*    The body of the scheduler which consists in a infinite loop      */
;*    executing instants.                                              */
;*---------------------------------------------------------------------*/
(define (schedule scdl::%scheduler)
   (with-access::%scheduler scdl (%builtin next-instant)
      (let loop ((i 0))
	 (%schedule-instant scdl)
	 (next-instant scdl i)
	 (loop (+fx i 1)))
      #unspecified))

;*---------------------------------------------------------------------*/
;*    scheduler-react! ...                                             */
;*    -------------------------------------------------------------    */
;*    Blocks the current thread (or program), executes one instant     */
;*    of the specified scheduler and returns its state.                */
;*---------------------------------------------------------------------*/
(define (scheduler-react! . o)
   (let ((scdl (%get-optional-scheduler 'scheduler-react! o)))
      ;; set temporarily the new value of the current scheduler
      (with-current-scheduler scdl
	 ;;; the body executed for the new current scheduler
         (lambda (scdl)
	    (with-access::%scheduler scdl (next-instant)
	       (set! next-instant
		     (lambda (scdl i)
			(%pthread-leave-scheduler (scheduler-%builtin scdl))
			#t))
	       ;; acquire the global cpu lock
	       (%pthread-enter-scheduler (scheduler-%builtin scdl))
	       ;; return a description of new state
	       (scheduler-state scdl))))))

;*---------------------------------------------------------------------*/
;*    scheduler-start! ...                                             */
;*---------------------------------------------------------------------*/
(define (scheduler-start! . args)
   (let* ((iterp (and (pair? args) (number? (car args))))
	  (scdl (if (null? args)
		    (default-scheduler)
		    (%get-optional-scheduler 'scheduler-start! (cdr args))))
	  (stop (cond
		   ((null? args)
		    (lambda (i)
		       #f))
		   ((number? (car args))
		    (let ((st (+ (car args) (%scheduler-time scdl) -1)))
		       (lambda (i)
			  (>= i st))))
		   ((procedure? (car args))
		    (lambda (i)
		       ((car args) i)))
		   (else
		    (error "scheduler-start!"
			   "Illegal optional parameter"
			   args)))))
      (define (busy-waiting-next-instant scdl i)
	 (if (stop i)
	     (begin
		(%pthread-leave-scheduler (scheduler-%builtin scdl))
		#unspecified)
	     (let ((state (scheduler-state scdl)))
		(with-trace 2 'busy-waiting-next-instant
		   (trace-item "state=" state))
		(case state
		   ((ready)
		    #t)
		   ((await)
		    ;; busy waiting mode
		    #t)
		   (else
		    (%pthread-leave-scheduler (scheduler-%builtin scdl))
		    #t)))))
      (define (no-busy-waiting-next-instant scdl i)
	 (if (stop i)
	     (begin
		(%pthread-leave-scheduler (scheduler-%builtin scdl))
		#unspecified)
	     (let ((state (scheduler-state scdl)))
		(with-trace 2 'no-busy-waiting-next-instant
		   (trace-item "state=" state))
		(case state
		   ((ready)
		    #t)
		   ((await)
		    ;;; the synchronized body
		    (with-access::%scheduler scdl (%builtin
						   tobroadcast
						   async-runnable)
		       (%async-synchronize %builtin)
		       ;; it might be possible that an asynchronous
		       ;; event has been broadcast since we have
		       ;; computed the scheduler state
		       (if (and (null? tobroadcast) (null? async-runnable))
			   (begin
			      (%async-scheduler-wait %builtin)
			      #unspecified))
		       (%async-asynchronize %builtin)
		       #t))
		   (else
		    (%pthread-leave-scheduler (scheduler-%builtin scdl))
		    #t)))))
      (with-current-scheduler scdl
	 ;;; the body executed within the current scheduler
	 (lambda (scdl)
	    (with-access::%scheduler scdl (%builtin next-instant)
	       (set! next-instant
		     (if iterp
			 busy-waiting-next-instant
			 no-busy-waiting-next-instant))
	       ;; acquires the global cpu lock
	       (%pthread-enter-scheduler (scheduler-%builtin scdl))
	       #unspecified)))))

;*---------------------------------------------------------------------*/
;*    broadcast! ...                                                   */
;*---------------------------------------------------------------------*/
(define (broadcast! sig . val)
   (let ((t (current-thread))
	 (v (if (pair? val) (car val) #unspecified)))
      (if (thread? t)
	  (if (%thread-attached? t)
	      (with-access::fthread t (scheduler)
		 (%broadcast! scheduler sig v))
	      (error "broadcast!" "Unattached thread" t)))))

;*---------------------------------------------------------------------*/
;*    scheduler-broadcast! ...                                         */
;*---------------------------------------------------------------------*/
(define (scheduler-broadcast! s sig . val)
   (%scheduler-add-broadcast! s sig (if (pair? val) (car val) #unspecified)))

;*---------------------------------------------------------------------*/
;*    scheduler-terminate! ...                                         */
;*---------------------------------------------------------------------*/
(define (scheduler-terminate! . s)
   (let ((s (cond
	       ((null? s)
		(default-scheduler))
	       ((scheduler? (car s))
		(car s))
	       (else
		(error "scheduler-react!"
		       "Illegal scheduler"
		       (car s))))))
      (with-access::%scheduler s (tosuspend/resume
				  tostart
				  threads-runnable
				  threads-yield
				  threads-timeout
				  current-thread
				  env+)
	 (with-trace 3 'scheduler-terminate!
	    (trace-item "s=" s)
	    (trace-item "current-thread=" current-thread)
	    (trace-item "tosuspend/resume=" tosuspend/resume)
	    (trace-item "threads-runnable=" threads-runnable)
	    (trace-item "thread-yield=" threads-yield)
	    (trace-item "thread-timeout=" threads-timeout)
	    (trace-item "thread-waiting=" (%scheduler-waiting-threads s))
	    ;; terminate all the running threads
	    (thread-terminate! current-thread)
	    (for-each thread-terminate! tosuspend/resume)
	    (for-each thread-terminate! threads-runnable)
	    (for-each thread-terminate! threads-yield)
	    (for-each thread-terminate! threads-timeout)
	    ;; terminate all the threads waiting for an event
	    (for-each thread-terminate! (%scheduler-waiting-threads s))
	    ;; reset all threads lists
	    (set! tosuspend/resume '())
	    (set! tostart '())
	    ;; mark that the scheduler must terminate at the end of instant
	    (%thread-is-dead s #t)))))

;*---------------------------------------------------------------------*/
;*    scheduler-instant ...                                            */
;*---------------------------------------------------------------------*/
(define (scheduler-instant . s)
   (let ((s (cond
	       ((null? s)
		(default-scheduler))
	       ((scheduler? (car s))
		(car s))
	       (else
		(error "scheduler-react!" "Illegal scheduler" (car s))))))
      (with-access::%scheduler s (env+)
	 (ftenv-instant (car env+)))))
