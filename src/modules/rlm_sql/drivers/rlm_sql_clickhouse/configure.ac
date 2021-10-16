AC_INIT(rlm_sql_clickhouse.c)
AC_REVISION($Revision$)
AC_DEFUN(modname,[rlm_sql_clickhouse])

fail=
SMART_LIBS=
SMART_CLFAGS=
SMART_CXXLFAGS=
if test x$with_[]modname != xno; then

	AC_PROG_CC
	AC_PROG_CXX
	SMART_LIBS="-lclickhouse-cpp-lib"

	targetname=modname
else
	targetname=
	echo \*\*\* module modname is disabled.
fi

if test x"$fail" != x""; then
	if test x"${enable_strict_dependencies}" = x"yes"; then
		AC_MSG_ERROR([set --without-]modname[ to disable it explicitly.])
	else
		AC_MSG_WARN([silently not building ]modname[.])
		AC_MSG_WARN([FAILURE: ]modname[ requires: $fail.])
		if test x"$headersuggestion" != x; then
			AC_MSG_WARN([$headersuggestion])
		fi
		if test x"$libsuggestion" != x; then
			AC_MSG_WARN([$libsuggestion])
		fi
		targetname=""
	fi
fi

mod_ldflags="$SMART_LIBS"
mod_cflags="$SMART_CFLAGS"
mod_cxxflags="$SMART_CXXFLAGS"
AC_SUBST(mod_ldflags)
AC_SUBST(mod_cflags)
AC_SUBST(mod_cxxflags)
AC_SUBST(targetname)
AC_CONFIG_HEADER(config.h)
AC_OUTPUT(all.mk)
