/*=====================================================================*/
/*    serrano/prgm/project/bigloo/runtime/Clib/ctrace.c                */
/*    -------------------------------------------------------------    */
/*    Author      :  Manuel Serrano                                    */
/*    Creation    :  Fri Mar 31 18:06:36 1995                          */
/*    Last change :  Wed Apr 21 15:15:57 2010 (serrano)                */
/*    -------------------------------------------------------------    */
/*    We dump a execution trace                                        */
/*=====================================================================*/
#include <bigloo.h>

/*---------------------------------------------------------------------*/
/*    void                                                             */
/*    bgl_init_trace ...                                               */
/*---------------------------------------------------------------------*/
BGL_RUNTIME_DEF
void
bgl_init_trace() {
   obj_t env = BGL_CURRENT_DYNAMIC_ENV();

   BGL_DYNAMIC_ENV( env ).top.symbol = BUNSPEC;
   BGL_DYNAMIC_ENV( env ).top.link = 0;

   BGL_ENV_SET_TOP_OF_FRAME( env, &(BGL_DYNAMIC_ENV( env ).top) );
}

/*---------------------------------------------------------------------*/
/*    obj_t                                                            */
/*    get_trace_stack ...                                              */
/*---------------------------------------------------------------------*/
BGL_RUNTIME_DEF obj_t
get_trace_stack( int depth ) {
   long level = 0L;
   struct bgl_dframe *runner = BGL_ENV_GET_TOP_OF_FRAME( BGL_CURRENT_DYNAMIC_ENV() );
   obj_t l = BNIL;

   while( ((depth < 0) || (level < depth)) && runner ) {
      if( SYMBOLP( runner->symbol ) ) {
	 l = MAKE_PAIR( runner->symbol, l );
	 level++; 
      }
      
      runner = runner->link;
   }
   
   return bgl_reverse_bang( l );
}

/*---------------------------------------------------------------------*/
/*    obj_t                                                            */
/*    cref ...                                                         */
/*---------------------------------------------------------------------*/
obj_t
cref( obj_t obj ) {
   return CREF( obj );
}

/*---------------------------------------------------------------------*/
/*    obj_t                                                            */
/*    car ...                                                          */
/*---------------------------------------------------------------------*/
obj_t
car( obj_t obj ) {
   return CAR( obj );
}

/*---------------------------------------------------------------------*/
/*    obj_t                                                            */
/*    cdr ...                                                          */
/*---------------------------------------------------------------------*/
obj_t
cdr( obj_t obj ) {
   return CDR( obj );
}

/*---------------------------------------------------------------------*/
/*    void                                                             */
/*    byteshow ...                                                     */
/*---------------------------------------------------------------------*/
static void
byteshow( unsigned char *addr ) {
#define PP_CHAR( c ) (((c) >= 33) && ((c) < 127)) ? c : '.'

   printf( "  %08lx  :  %02x %02x %02x %02x  :  %c%c%c%c\n",
           (unsigned long)addr,
           addr[ 0 ],
           addr[ 1 ],
           addr[ 2 ],
           addr[ 3 ],
           PP_CHAR( addr[ 0 ] ),
           PP_CHAR( addr[ 1 ] ),
           PP_CHAR( addr[ 2 ] ),
           PP_CHAR( addr[ 3 ] ) );
}
             
/*---------------------------------------------------------------------*/
/*    void                                                             */
/*    memshow ...                                                      */
/*---------------------------------------------------------------------*/
void
memshow( char *from, char *to, long step ) {
   char *i;

   step *= 4;
      
   if( from > to )
      for( i = from; i > to; i -= step )
         byteshow( (unsigned char *)i );
   else
      for( i = from; i < to; i += step )
         byteshow( (unsigned char *)i );

   puts( "" );
   return ;
}
