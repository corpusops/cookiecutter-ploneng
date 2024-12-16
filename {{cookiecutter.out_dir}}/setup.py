#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os
from setuptools import setup, find_packages

def read(*rnames):
    return open(
        os.path.join(".", *rnames)
    ).read()
READMES = [a for a in ['README', 'README.rst', 'README.md', 'README.txt']
           if os.path.exists(a)]
long_description = "\n\n".join(READMES)
classifiers = [
    "Environment :: Web Environment",
    "Framework :: Plone",
    "Framework :: Plone :: Addon",
    "Framework :: Plone :: Distribution",
    "Framework :: Plone :: 6.0",
    "Programming Language :: Python",
    "Programming Language :: Python :: 3.8",
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Operating System :: OS Independent",
    "License :: OSI Approved :: GNU General Public License v2 (GPLv2)",
]
name = '{{cookiecutter.plone_project_name}}'
version = "1.0"
src_dir = 'src'
install_requires = [
    "z3c.jbot",
{%- if cookiecutter.with_eea %}
    "eea.facetednavigation",
{%- endif %}
{%- if cookiecutter.with_exportimport %}
    "collective.exportimport",
{%- endif %}
]
extra_requires = {}
candidates = {}
entry_points = {
    "z3c.autoinclude.plugin": ["target = plone"],
    "console_scripts": ["update_dist_locale={{cookiecutter.plone_project_name}}.locales.update:update_locale"],
    # "console_scripts": ["foo = foo:main"],
}
setup(name=name,
      version=version,
      namespace_packages=[],
      description=name,
      long_description=long_description,
      classifiers=classifiers,
      keywords="",
      author="{{cookiecutter.author}}",
      author_email="{{cookiecutter.mail}}",
      url="{{cookiecutter.git_project_url}}",
      license="{{cookiecutter.license}}",
      packages=find_packages(src_dir),
      package_dir={"": src_dir},
      include_package_data=True,
      install_requires=install_requires,
      extras_require=extra_requires,
      entry_points=entry_points)
# vim:set ft=python:
