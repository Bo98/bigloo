/*=====================================================================*/
/*    serrano/prgm/project/bigloo/runtime/Include/bigloo_string.h      */
/*    -------------------------------------------------------------    */
/*    Author      :  Manuel Serrano                                    */
/*    Creation    :  Sat Mar  5 08:05:01 2016                          */
/*    Last change :  Fri Apr  1 07:32:45 2016 (serrano)                */
/*    Copyright   :  2016 Manuel Serrano                               */
/*    -------------------------------------------------------------    */
/*    Bigloo STRINGs                                                   */
/*=====================================================================*/
#ifndef BIGLOO_STRING_H 
#define BIGLOO_STRING_H

/*---------------------------------------------------------------------*/
/*    Does someone really wants C++ here?                              */
/*---------------------------------------------------------------------*/
#ifdef __cplusplus
extern "C" {
#endif
#ifdef __cplusplus_just_for_emacs_indent
}
#endif

/*---------------------------------------------------------------------*/
/*    extern                                                           */
/*---------------------------------------------------------------------*/
BGL_RUNTIME_DECL obj_t make_string_sans_fill();
BGL_RUNTIME_DECL obj_t string_to_bstring( char * );
BGL_RUNTIME_DECL obj_t string_to_bstring_len( char *, int );
BGL_RUNTIME_DECL obj_t close_init_string();
BGL_RUNTIME_DECL obj_t bgl_string_shrink( obj_t, long );
BGL_RUNTIME_DECL bool_t bigloo_strcmp( obj_t, obj_t );
					
#if( BGL_HAVE_UNISTRING )
BGL_RUNTIME_DECL int bgl_strcoll( obj_t, obj_t );
#endif					

/*---------------------------------------------------------------------*/
/*    bgl_string ...                                                   */
/*---------------------------------------------------------------------*/
struct bgl_string {
#if( !defined( TAG_STRING ) )
   header_t header;
#endif		
   long length;
   long sentinel;
   unsigned char char0[ 1 ];
};

struct bgl_ucs2_string {
   header_t header;
   long length;
   ucs2_t char0;
};   

#define STRING( o ) (CSTRING( o )->string_t)
#define UCS2_STRING( o )  (CUCS2STRING( o )->ucs2_string_t)

#define STRING_SIZE (sizeof( struct bgl_string ))
#define UCS2_STRING_SIZE (sizeof( struct bgl_ucs2_string ))

/*---------------------------------------------------------------------*/
/*    tagging                                                          */
/*---------------------------------------------------------------------*/
#if( defined( TAG_STRING ) )
#   define BSTRING( p ) ((obj_t)((long)p + TAG_STRING))
#   define CSTRING( p ) ((obj_t)((long)p - TAG_STRING))
#   define STRINGP( c ) ((c && ((((long)c)&TAG_MASK) == TAG_STRING)))
#else
#   define BSTRING( p ) BREF( p )
#   define CSTRING( p ) ((obj_t)((unsigned long)(p) - TAG_STRUCT))
#   define STRINGP( c ) (POINTERP( c ) && (TYPE( c ) == STRING_TYPE))
#endif

#define BUCS2STRING( p ) BREF( p )
#define CUCS2STRING( p ) CREF( p )

#define UCS2_STRINGP( c ) (POINTERP( c ) && (TYPE( c ) == UCS2_STRING_TYPE))

/*---------------------------------------------------------------------*/
/*    alloc                                                            */
/*---------------------------------------------------------------------*/
/* When producing C code for a compiler that is unable to    */
/* accept large splitted string, Bigloo emits a declaration  */
/* of a C characters array. This requires 2 macros, one for  */
/* starting the declaration and one for ending it. The       */
/* array itself, is inserted in between the two macros by    */
/* bigloo such as:                                           */
/*        DEFINE_STRING_START( f, a, 2 ),                    */
/*          {45,46,0},                                       */
/*        DEFINE_STRING_STOP( f, a, 2 );                     */
#if( defined( TAG_STRING ) )
#   define DEFINE_STRING( name, aux, str, len ) \
   static struct { __CNST_ALIGN long length;
                      long sentinel; \
                      char string[ len + 1 ]; } \
         aux = { __CNST_FILLER, len, 0, str }; \
         static obj_t name = BSTRING( &(aux.length) )
#   define DEFINE_STRING_ASCII_SENTINEL( name, aux, str, len, sen ) \
   static struct { __CNST_ALIGN long length;
                      long sentinel; \
                      char string[ len + 1 ]; } \
         aux = { __CNST_FILLER, len, sen, str }; \
         static obj_t name = BSTRING( &(aux.length) )
#   define DEFINE_STRING_START( name, aux, len ) \
      static struct { __CNST_ALIGN long length; \
                      long sentinel; \
                      char string[ len + 1 ]; } \
         aux = { __CNST_FILLER, len, 0
#   define DEFINE_STRING_STOP( name, aux ) \
        }; static obj_t name = BSTRING( &(aux.length) 
#else
#   define DEFINE_STRING( name, aux, str, len ) \
      static struct { __CNST_ALIGN header_t header; \
                      long length; \
                      long sentinel; \
                      char string[ len + 1 ]; } \
         aux = { __CNST_FILLER, MAKE_HEADER( STRING_TYPE, 0 ), len, 0, str }; \
         static obj_t name = BSTRING( &(aux.header) )
#   define DEFINE_STRING_ASCII_SENTINEL( name, aux, str, len, sen ) \
      static struct { __CNST_ALIGN header_t header; \
                      long length; \
                      long sentinel; \
                      char string[ len + 1 ]; } \
         aux = { __CNST_FILLER, MAKE_HEADER( STRING_TYPE, sen ), len, sen, str }; \
         static obj_t name = BSTRING( &(aux.header) )
#   define DEFINE_STRING_START( name, aux, len ) \
      static struct { __CNST_ALIGN header_t header; \
                      long length; \
                      long sentinel; \
                      char string[ len + 1]; } \
         aux = { __CNST_FILLER, MAKE_HEADER( STRING_TYPE, 0 ), len, 0
#   define DEFINE_STRING_STOP( name, aux ) \
        }; static obj_t name = BSTRING( &(aux.header) )
#endif

/*---------------------------------------------------------------------*/
/*    api                                                              */
/*---------------------------------------------------------------------*/
#define STRING_LENGTH( s ) STRING( s ).length
#define INVERSE_STRING_LENGTH( s ) \
   ((STRING_LENGTH( s ) = (-STRING_LENGTH( s ))), BUNSPEC)
   
#define BSTRING_TO_STRING( s ) ((char *)(&(STRING( s ).char0)))

#define STRING_REF( v, i ) (((unsigned char *)BSTRING_TO_STRING( v ))[ i ])
#define STRING_SET( s, i, c ) (STRING_REF( s, i ) = c, BUNSPEC)
#define STRING_PTR_NULL( _p ) (_p == 0)

#define STRING_ASCII_SENTINEL( s ) \
   (STRING( s ).sentinel)
#define STRING_ASCII_SENTINEL_SET( s, i ) \
    (STRING_ASCII_SENTINEL( s ) = (i), s)

#define BGL_MEMCHR( s, c, n, i ) memchr( &s[ i ], c, n )
#define BGL_MEMCHR_ZERO( s ) ((s) == 0L)
#define BGL_MEMCHR_DIFF( s1, s2 ) ((s1) - (s2))
	 
#define UCS2_STRING_LENGTH( s ) UCS2_STRING( s ).length
#define INVERSE_UCS2_STRING_LENGTH( s ) \
   ((UCS2_STRING_LENGTH( s ) = (-UCS2_STRING_LENGTH( s ))), BUNSPEC)

#define BUCS2_STRING_TO_UCS2_STRING( s ) (&(UCS2_STRING( s ).char0))

#define UCS2_STRING_REF( v, i ) (BUCS2_STRING_TO_UCS2_STRING( v )[ i ])
#define UCS2_STRING_SET( s, i, c ) (UCS2_STRING_REF( s, i ) = c, BUNSPEC)
	    
/*---------------------------------------------------------------------*/
/*    C++                                                              */
/*---------------------------------------------------------------------*/
#ifdef __cplusplus
}
#endif
#endif
