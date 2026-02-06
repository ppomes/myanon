SUBDIRS = hmac main
dist_doc_DATA = README.md

EXTRA_DIST = $(top_srcdir)/uthash/uthash.h \
             $(top_srcdir)/main/myanon-sample.conf \
             $(top_srcdir)/debian/changelog \
             $(top_srcdir)/debian/compat \
             $(top_srcdir)/debian/control \
             $(top_srcdir)/debian/copyright \
             $(top_srcdir)/debian/rules

TULIST = test1 test1-insert-ignore null-example appendkey prependkey issue29 test_substring appendindex prependindex test_regex complex
PYTULIST = test_python test_large_python test_large_python_2
PYTHON_SUPPORT = @PYTHON_SUPPORT@

check: all
	@rc=0; \
	for ut in $(TULIST); do \
		main/myanon -f tests/$${ut}.conf < tests/$${ut}.sql | diff tests/$${ut}_anon.sql - > /dev/null; \
		if [ $$? -eq 0 ]; then \
		  echo "Test $${ut} OK" >&2; \
		else \
	          echo "Test $${ut} FAILED" >&2; \
		  rc=1; \
		fi \
	done; \
	if test "x$(PYTHON_SUPPORT)" = "xyes"; then \
		for ut in $(PYTULIST); do \
			main/myanon -f tests/$${ut}.conf < tests/$${ut}.sql | diff tests/$${ut}_anon.sql - > /dev/null; \
			if [ $$? -eq 0 ]; then \
				echo "Test $${ut} OK" >&2; \
			else \
				echo "Test $${ut} FAILED" >&2; \
				rc=1; \
			fi \
		done; \
	fi; \
	exit $$rc

valgrind-check: all
	@if [ "$$(uname)" != "Linux" ]; then echo "valgrind-check is only supported on Linux" >&2; exit 1; fi
	@which valgrind > /dev/null 2>&1 || { echo "valgrind not found" >&2; exit 1; }
	@rc=0; \
	for ut in $(TULIST); do \
		valgrind --leak-check=full --error-exitcode=99 main/myanon -f tests/$${ut}.conf < tests/$${ut}.sql 2>valgrind_$${ut}.log | diff tests/$${ut}_anon.sql - > /dev/null; \
		vrc=$$?; \
		leaks=$$(grep "definitely lost:" valgrind_$${ut}.log | grep -v "0 bytes" || true); \
		errors=$$(grep "ERROR SUMMARY:" valgrind_$${ut}.log | grep -v "0 errors" || true); \
		if [ $$vrc -eq 0 ] && [ -z "$$leaks" ] && [ -z "$$errors" ]; then \
			echo "Test $${ut} OK (valgrind clean)" >&2; \
		else \
			echo "Test $${ut} FAILED (see valgrind_$${ut}.log)" >&2; \
			rc=1; \
		fi; \
		rm -f valgrind_$${ut}.log; \
	done; \
	if test "x$(PYTHON_SUPPORT)" = "xyes"; then \
		for ut in $(PYTULIST); do \
			valgrind --leak-check=full --error-exitcode=99 main/myanon -f tests/$${ut}.conf < tests/$${ut}.sql 2>valgrind_$${ut}.log | diff tests/$${ut}_anon.sql - > /dev/null; \
			vrc=$$?; \
			leaks=$$(grep "definitely lost:" valgrind_$${ut}.log | grep -v "0 bytes" || true); \
			errors=$$(grep "ERROR SUMMARY:" valgrind_$${ut}.log | grep -v "0 errors" || true); \
			if [ $$vrc -eq 0 ] && [ -z "$$leaks" ] && [ -z "$$errors" ]; then \
				echo "Test $${ut} OK (valgrind clean)" >&2; \
			else \
				echo "Test $${ut} FAILED (see valgrind_$${ut}.log)" >&2; \
				rc=1; \
			fi; \
			rm -f valgrind_$${ut}.log; \
		done; \
	fi; \
	exit $$rc

.PHONY: check valgrind-check
