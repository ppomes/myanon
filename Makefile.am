SUBDIRS = hmac main
dist_doc_DATA = README.md

EXTRA_DIST = $(top_srcdir)/uthash/uthash.h \
             $(top_srcdir)/main/myanon-sample.conf \
             $(top_srcdir)/debian/changelog \
             $(top_srcdir)/debian/compat \
             $(top_srcdir)/debian/control \
             $(top_srcdir)/debian/copyright \
             $(top_srcdir)/debian/rules

TULIST = test1 null-example concat

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
	exit $$rc

.PHONY: check
