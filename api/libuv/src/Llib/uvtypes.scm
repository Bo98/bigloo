;*=====================================================================*/
;*    serrano/prgm/project/bigloo/api/libuv/src/Llib/uvtypes.scm       */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Tue May  6 11:55:29 2014                          */
;*    Last change :  Wed May 14 10:19:17 2014 (serrano)                */
;*    Copyright   :  2014 Manuel Serrano                               */
;*    -------------------------------------------------------------    */
;*    LIBUV types                                                      */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __libuv_types

   (include "uv.sch")
   
   (export (abstract-class %Uv
	      (%uv-init))

	   (class UvHandle::%Uv
	      ($builtin::$uv_handle_t (default $uv_handle_nil))
	      (onclose (default #f)))
	   
	   (class UvLoop::UvHandle
	      (%mutex::mutex read-only (default (make-mutex)))
	      (%gcmarks::pair-nil (default '())))

	   (abstract-class UvWatcher::UvHandle
	      (cb::procedure (default list))
	      (loop::UvLoop read-only))
	   
	   (class UvTimer::UvWatcher)

	   (class UvAsync::UvWatcher)

	   (generic %uv-init ::UvHandle)))

;*---------------------------------------------------------------------*/
;*    %uv-init ...                                                     */
;*---------------------------------------------------------------------*/
(define-generic (%uv-init o)
   o)

;*---------------------------------------------------------------------*/
;*    object-print ...                                                 */
;*---------------------------------------------------------------------*/
(define-method (object-print obj::%Uv port print-slot::procedure)
   
   (define (class-field-write/display field)
      (let* ((name (class-field-name field))
	     (get-value (class-field-accessor field))
	     (s (symbol->string! name)))
	 (unless (memq (string-ref s 0) '(#\$ #\%))
	    (display " [" port)
	    (display name port)
	    (display #\: port)
	    (display #\space port)
	    (print-slot (get-value obj) port)
	    (display #\] port))))

   (let* ((class (object-class obj))
	  (class-name (class-name class))
	  (fields (class-all-fields class))
	  (len (vector-length fields)))
      (display "#|" port)
      (display class-name port)
      (if (nil? obj)
	  (display " nil|" port)
	  (let loop ((i 0))
	     (if (=fx i len)
		 (display #\| port)
		 (begin
		    (class-field-write/display (vector-ref-ur fields i))
		    (loop (+fx i 1))))))))