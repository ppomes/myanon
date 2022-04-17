SUBDIRS = hmac main
dist_doc_DATA = README.md

EXTRA_DIST = $(top_srcdir)/uthash/uthash.h \
             $(top_srcdir)/main/myanon-sample.conf \
             $(top_srcdir)/debian/changelog \
             $(top_srcdir)/debian/compat \
             $(top_srcdir)/debian/control \
             $(top_srcdir)/debian/copyright \
             $(top_srcdir)/debian/rules

TESTS = test1 null-example

tests: all
	@for ut in $(TESTS); do \
		main/myanon -f tests/$${ut}.conf < tests/$${ut}.sql | diff tests/$${ut}_anon.sql - > /dev/null; \
                ([ $$? -eq 0 ] && echo "Test $${ut} OK" >&2) || echo "Test $${ut} FAILED" >&2; \
	done

.PHONY: tests
