# -*- coding: utf-8 -*-
"""Setup tests for this package."""
from {{cookiecutter.plone_project_name}}.testing import {{cookiecutter.plone_project_name.upper()}}_INTEGRATION_TESTING  # noqa
from plone import api
from plone.app.testing import setRoles
from plone.app.testing import TEST_USER_ID

import unittest


class TestSetup(unittest.TestCase):
    """Test that {{cookiecutter.plone_project_name}} is properly installed."""

    layer = {{cookiecutter.plone_project_name.upper()}}_INTEGRATION_TESTING

    def setUp(self):
        """Custom shared utility setup for tests."""
        self.portal = self.layer['portal']
        self.installer = api.portal.get_tool('portal_quickinstaller')

    def test_product_installed(self):
        """Test if {{cookiecutter.plone_project_name}} is installed."""
        self.assertTrue(self.installer.isProductInstalled(
            '{{cookiecutter.plone_project_name}}'))

    def test_browserlayer(self):
        """Test that I{{cookiecutter.plone_project_name.capitalize()}}Layer is registered."""
        from {{cookiecutter.plone_project_name}}.interfaces import (
            I{{cookiecutter.plone_project_name.capitalize()}}Layer)
        from plone.browserlayer import utils
        self.assertIn(
            I{{cookiecutter.plone_project_name.capitalize()}}Layer,
            utils.registered_layers())


class TestUninstall(unittest.TestCase):

    layer = {{cookiecutter.plone_project_name.upper()}}_INTEGRATION_TESTING

    def setUp(self):
        self.portal = self.layer['portal']
        self.installer = api.portal.get_tool('portal_quickinstaller')
        roles_before = api.user.get_roles(TEST_USER_ID)
        setRoles(self.portal, TEST_USER_ID, ['Manager'])
        self.installer.uninstallProducts(['{{cookiecutter.plone_project_name}}'])
        setRoles(self.portal, TEST_USER_ID, roles_before)

    def test_product_uninstalled(self):
        """Test if {{cookiecutter.plone_project_name}} is cleanly uninstalled."""
        self.assertFalse(self.installer.isProductInstalled(
            '{{cookiecutter.plone_project_name}}'))

    def test_browserlayer_removed(self):
        """Test that I{{cookiecutter.plone_project_name.capitalize()}}Layer is removed."""
        from {{cookiecutter.plone_project_name}}.interfaces import \
            I{{cookiecutter.plone_project_name.capitalize()}}Layer
        from plone.browserlayer import utils
        self.assertNotIn(
            I{{cookiecutter.plone_project_name.capitalize()}}Layer,
            utils.registered_layers())
