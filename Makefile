# This file is part of Simpleline Text UI library.
#
# Copyright (C) 2020  Red Hat, Inc.
#
# Simpleline is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Simpleline is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Simpleline.  If not, see <https://www.gnu.org/licenses/>.

PKGNAME=simpleline
SPECNAME=python-$(PKGNAME)
VERSION=$(shell awk '/Version:/ { print $$2 }' $(SPECNAME).spec)
RELEASE=$(shell awk '/Release:/ { print $$2 }' $(SPECNAME).spec | sed -e 's|%.*$$||g')
TAG=$(PKGNAME)-$(VERSION)

PREFIX=/usr

PYTHON=python3

ZANATA_PULL_ARGS = --transdir po/
ZANATA_PUSH_ARGS = --srcdir po/ --push-type source --force

default: all

.PHONY: all
all:
	$(MAKE) -C po

.PHONY: clean
clean:
	-rm *.tar.gz simpleline/*.pyc tests/*.pyc ChangeLog
	$(MAKE) -C po clean
	$(PYTHON) setup.py -q clean --all

.PHONY: test
test:
	@echo "*** Running unittests ***"
	PYTHONPATH=. $(PYTHON) -m unittest discover -v -s tests/ -p '*_test.py'

.PHONY: check
check:
	@echo "*** Running pocketlint ***"
	PYTHONPATH=. tests/pylint/runpylint.py

.PHONY: install
install:
	$(PYTHON) setup.py install --root=$(DESTDIR)
	$(MAKE) -C po install

.PHONY: ChangeLog
ChangeLog:
	(GIT_DIR=.git git log > .changelog.tmp && mv .changelog.tmp ChangeLog; rm -f .changelog.tmp) || (touch ChangeLog; echo 'git directory not found: installing possibly empty changelog.' >&2)

.PHONY: tag
tag:
	git tag -a -m "Tag as $(TAG)" -f $(TAG)
	@echo "Tagged as $(TAG)"

.PHONY: release
release: tag archive

.PHONY: archive
archive: po-pull ChangeLog
	$(PYTHON) setup.py sdist bdist_wheel
	@echo "The archive is in dist/$(PKGNAME)-$(VERSION).tar.gz"

.PHONY: rpmlog
rpmlog:
	@git log --no-merges --pretty="format:- %s (%ae)" $(TAG).. |sed -e 's/@.*)/)/'
	@echo

.PHONY: potfile
potfile:
	$(MAKE) -C po potfile

.PHONY: po-pull
po-pull:
	which zanata &>/dev/null || ( echo "need to install zanata python client"; exit 1 )
	zanata pull $(ZANATA_PULL_ARGS)

.PHONY: po-push
po-push: potfile
	zanata push $(ZANATA_PUSH_ARGS) || ( echo "zanata push failed"; exit 1 )

.PHONY: bumpver
bumpver: po-push
	@NEWSUBVER=$$((`echo $(VERSION) |cut -d . -f 2` + 1)) ; \
	NEWVERSION=`echo $(VERSION).$$NEWSUBVER |cut -d . -f 1,3` ; \
	DATELINE="* `LC_ALL=C.UTF-8 date "+%a %b %d %Y"` `git config user.name` <`git config user.email`> - $$NEWVERSION-1"  ; \
	cl=`grep -n %changelog $(SPECNAME).spec |cut -d : -f 1` ; \
	tail --lines=+$$(($$cl + 1)) $(SPECNAME).spec > speclog ; \
	(head -n $$cl $(SPECNAME).spec ; echo "$$DATELINE" ; make --quiet rpmlog 2>/dev/null ; echo ""; cat speclog) > $(SPECNAME).spec.new ; \
	mv $(SPECNAME).spec.new $(SPECNAME).spec ; rm -f speclog ; \
	sed -i "s/Version: $(VERSION)/Version: $$NEWVERSION/" $(SPECNAME).spec ; \
	sed -i "s/version='$(VERSION)'/version='$$NEWVERSION'/" setup.py

.PHONY: ci
ci: check test
