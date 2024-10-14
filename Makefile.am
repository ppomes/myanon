SUBDIRS = hmac main
dist_doc_DATA = README.md

EXTRA_DIST = $(top_srcdir)/uthash/uthash.h \
             $(top_srcdir)/main/myanon-sample.conf \
             $(top_srcdir)/debian/changelog \
             $(top_srcdir)/debian/compat \
             $(top_srcdir)/debian/control \
             $(top_srcdir)/debian/copyright \
             $(top_srcdir)/debian/rules

TULIST = test1 test1-insert-ignore null-example appendkey prependkey issue29 test_substring appendindex prependindex
PYTHON_SUPPORT = @PYTHON_SUPPORT@
JQ_SUPPORT = @JQ@

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
		main/myanon -f tests/test_python.conf < tests/test_python.sql | diff tests/test_python_anon.sql - > /dev/null; \
		if [ $$? -eq 0 ]; then \
		  echo "Test test_python OK" >&2; \
		else \
		  echo "Test test_python FAILED" >&2; \
		  rc=1; \
		fi \
	fi; \
        if test "x$(JQ)" = "xyes"; then \
                export PYTHONPATH="$(PWD)/tests:$$PYTHONPATH"; \
                main/myanon -f tests/complex.conf < tests/complex.sql | diff tests/complex_anon.sql - > /dev/null; \
                if [ $$? -eq 0 ]; then \
                  echo "Test JQ OK" >&2; \
                else \
                  echo "Test JQ FAILED" >&2; \
                  rc=1; \
                fi \
        fi; \
	exit $$rc

.PHONY: check
