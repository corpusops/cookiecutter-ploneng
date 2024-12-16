# -*- coding: utf-8 -*-
"""Init and utils."""
from zope.i18nmessageid import MessageFactory
import logging

_ = MessageFactory('{{cookiecutter.plone_project_name}}')
logger = logging.getLogger("{{cookiecutter.plone_project_name}}")
