#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2009 Fermi Research Alliance, LLC
# SPDX-License-Identifier: Apache-2.0

"""Unit test for glideinwms/lib/util.py
"""


import unittest

import xmlrunner

from glideinwms.lib.util import is_str_safe


class TestUtilFunctions(unittest.TestCase):
    def setUp(self):
        pass

    def test_is_str_safe(self):
        s1 = "//\\"
        self.assertFalse(is_str_safe(s1))
        s2 = "lalalala"
        self.assertTrue(is_str_safe(s2))


if __name__ == "__main__":
    unittest.main(testRunner=xmlrunner.XMLTestRunner(output="unittests-reports"))
