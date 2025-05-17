AC_INIT([myanon], [0.7], [pierre.pomes@gmail.com])
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE([-Wall -Werror foreign])
AC_CONFIG_SRCDIR([config.h.in])
AC_CONFIG_HEADERS([config.h])

# Checks for programs.
AC_PROG_CC
AC_PROG_YACC
AC_PROG_LEX(noyywrap)
AC_PROG_INSTALL
AM_PROG_AR
AC_PROG_RANLIB

# Arguments
AC_ARG_ENABLE([python],
              [AS_HELP_STRING([--enable-python],
                              [enable @<:@default=no@:>@ Python support @<:@default=no@:>@])],
              [enable_python=$enableval],
              [enable_python="no"])

AC_ARG_ENABLE([jq],
              [AS_HELP_STRING([--enable-jq],
                              [enable @<:@default=no@:>@ jq support @<:@default=no@:>@])],
              [enable_jq=$enableval],
              [enable_jq="no"])

# Checks flex/bison version
AC_PATH_PROG([FLEX],[flex])
AX_PROG_FLEX_VERSION([2.6.0],,AC_MSG_ERROR([GNU flex 2.6+ is required]))

AC_PATH_PROG([BISON],[bison])
AX_PROG_BISON_VERSION([3.0.0],,AC_MSG_ERROR([GNU bison v3+ is required]))

# Checks for header files.
AC_CHECK_HEADERS(stdio.h, ,[AC_MSG_ERROR([Cannot find stdio.h header])])
AC_CHECK_HEADERS(stddef.h, ,[AC_MSG_ERROR([Cannot find stddef.h header])])
AC_CHECK_HEADERS(stdlib.h, ,[AC_MSG_ERROR([Cannot find stdlib.h header])])
AC_CHECK_HEADERS(stdbool.h, ,[AC_MSG_ERROR([Cannot find stdbool.h header])])
AC_CHECK_HEADERS(stdint.h, ,[AC_MSG_ERROR([Cannot find stdint.h header])])
AC_CHECK_HEADERS(strings.h, ,[AC_MSG_ERROR([Cannot find string.h header])])
AC_CHECK_HEADERS(errno.h, ,[AC_MSG_ERROR([Cannot find errno.h header])])
AC_CHECK_HEADERS(getopt.h, ,[AC_MSG_ERROR([Cannot find getopt.h header])])
AC_CHECK_HEADERS(sys/time.h, ,[AC_MSG_ERROR([Cannot find sys/time.h header])])

# Check python dependencies
if test "$enable_python" = "yes"; then
    AM_PATH_PYTHON([3])
    AC_ARG_VAR([PYTHON_INCLUDE], [Include flags for python, bypassing python-config])
    AC_ARG_VAR([PYTHON_LIBS], [ldflags flags for python, bypassing python-config])
    AC_PATH_PROGS([PYTHON_CONFIG],
                   [python$PYTHON_VERSION-config python-config],
                   [no],
                   [`dirname $PYTHON`])
    AS_IF([test "$PYTHON_CONFIG" = no], [AC_MSG_ERROR([cannot find python-config for $PYTHON.])])
    AC_MSG_CHECKING([python include flags])
    PYTHON_INCLUDE=`$PYTHON_CONFIG --includes`
    AC_MSG_RESULT([$PYTHON_INCLUDE])
    AC_MSG_CHECKING([python ldflags flags])
    PYTHON_LIBS=`$PYTHON_CONFIG --embed --ldflags`
    AC_MSG_RESULT([$PYTHON_LIBS])

    AC_SUBST([PYTHON_LIBS])

    CPPFLAGS="$CPPFLAGS $PYTHON_INCLUDE"
    LDFLAGS="$LDFLAGS $PYTHON_LIBS"

    AC_DEFINE([HAVE_PYTHON], ["yes"], [Define to "yes" if Python support is enabled.])
    AC_SUBST([PYTHON_SUPPORT], [$enable_python])
fi

# Check jq dependencies
if test "x$enable_jq" = "xyes"; then
   AC_CHECK_LIB([jq], [jq_init], [], [AC_MSG_ERROR([libjq not found])])

   AC_DEFINE([HAVE_JQ], ["yes"], [Define to "yes" if JQ support is enabled.])
   AC_SUBST([JQ], [$enable_jq])
fi

AC_CONFIG_FILES([Makefile
                 hmac/Makefile
                 main/Makefile])
AC_OUTPUT
