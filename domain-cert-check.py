#!/usr/bin/env python

# Display renewal dates for a list of domains given on the command line.
# Copyright 2021 by Akkana Peck; share and enjoy under the GPLv3 or later.

from __future__ import print_function
import sys
import socket
import datetime
import calendar

# pyright: reportMissingImports=false
_dependency_fallback_whois = False
try:
    import whois
except ImportError:
    class whois:
        class parser:
            class PywhoisError(Exception):
                pass

        @staticmethod
        def _normalize_domain(domainname):
            return domainname.strip().rstrip('.').lower()

        @staticmethod
        def _parse_date(value):
            value = value.strip()
            if not value:
                return None
            if value.endswith('Z'):
                value = value[:-1] + '+00:00'
            for fmt in (
                '%Y-%m-%d',
                '%Y-%m-%d %H:%M:%S',
                '%Y-%m-%dT%H:%M:%S',
                '%Y-%m-%d %H:%M:%S%z',
                '%Y-%m-%dT%H:%M:%S%z',
            ):
                try:
                    return datetime.datetime.strptime(value, fmt).date()
                except ValueError:
                    pass
            try:
                return datetime.datetime.fromisoformat(value).date()
            except ValueError:
                return None

        @staticmethod
        def _extract_expiration_date(raw_text):
            for line in raw_text.splitlines():
                text = line.strip()
                if not text:
                    continue
                lowered = text.lower()
                if any(token in lowered for token in (
                    'registry expiry date',
                    'domain expires',
                    'paid-till',
                    'renewal date',
                    'expiration time',
                    'expires',
                    'renewal date',
                )):
                    candidate = text.split(':', 1)[1].strip() if ':' in text else text
                    exp_date = whois._parse_date(candidate)
                    if exp_date is not None:
                        return exp_date
            raise whois.parser.PywhoisError('No expiration date found in WHOIS response')

        @staticmethod
        def _query_server(domainname):
            domain = whois._normalize_domain(domainname)
            servers = ['whois.verisign-grs.com', 'whois.iana.org', 'whois.crsnic.net']
            for server in servers:
                try:
                    with socket.create_connection((server, 43), timeout=10) as sock:
                        sock.sendall((domain + '\r\n').encode('ascii'))
                        chunks = []
                        while True:
                            chunk = sock.recv(4096)
                            if not chunk:
                                break
                            chunks.append(chunk)
                            if len(chunk) < 4096:
                                break
                    raw = b''.join(chunks).decode('utf-8', 'replace')
                    if raw and 'no match for domain' not in raw.lower() and 'not found' not in raw.lower():
                        return raw
                except (OSError, socket.timeout):
                    continue
            raise whois.parser.PywhoisError('Unable to query WHOIS server for {}'.format(domainname))

        @staticmethod
        def whois(domainname):
            raw = whois._query_server(domainname)
            registrar = None
            for line in raw.splitlines():
                text = line.strip()
                if not text:
                    continue
                lowered = text.lower()
                if 'registrar' in lowered and ':' in text:
                    registrar = text.split(':', 1)[1].strip()
                    break
            result = type('WHOISResult', (), {
                'expiration_date': whois._extract_expiration_date(raw),
                'registrar': registrar,
            })()
            return result

        @staticmethod
        def query(domainname):
            return whois.whois(domainname)

    _dependency_fallback_whois = True
    print("""Couldn't import whois. Falling back to a minimal built-in WHOIS client.
For better results, install one of:
    apt install python3-whois
or
    pip3 install python-whois
""")

# Check all external dependencies before importing them or starting work.
import importlib as _dependency_importlib
import shutil as _dependency_shutil
import sys as _dependency_sys
import platform as _dependency_platform
_dependency_missing = []
_dependency_modules = ['whois']
_dependency_commands = []
if not _dependency_fallback_whois:
    for _dependency_module in _dependency_modules:
        try:
            _dependency_importlib.import_module(_dependency_module)
        except ImportError as _dependency_error:
            _dependency_missing.append('Python module "{}": {}'.format(_dependency_module, _dependency_error))
    for _dependency_command in _dependency_commands:
        if not _dependency_shutil.which(_dependency_command):
            _dependency_missing.append('command "{}" is not installed or not in PATH'.format(_dependency_command))
    if _dependency_missing:
        for _dependency_message in _dependency_missing:
            print('ERROR: ' + _dependency_message, file=_dependency_sys.stderr)
        raise SystemExit(1)

# ANSI color codes
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"

# Adjusted format to move date column one space to the right
format = "%25s %11s %3s %s"


def get_domain(domainname):
    if hasattr(whois, "query"):
        return get_domain_apt_python3whois(domainname)
    return get_domain_pip_pythonwhois(domainname)


RETRIES = 6


def get_domain_apt_python3whois(domainname):
    for _ in range(RETRIES):
        try:
            return whois.query(domainname)
        except Exception:
            print("Problem on", domainname, "retrying ...", file=sys.stderr)
    print("Giving up on %s after %d timeouts" % (domainname, RETRIES), file=sys.stderr)
    return None


def get_domain_pip_pythonwhois(domainname):
    for _ in range(RETRIES):
        try:
            domain = whois.whois(domainname)  # Fixed variable name from 'name' to 'domainname'
            return domain
        except socket.timeout:
            print("%s: timed out, retrying" % domainname, file=sys.stderr)
        except ConnectionResetError:
            print("%s: ConnectionResetError, retrying" % domainname, file=sys.stderr)
        except whois.parser.PywhoisError:
            print("%s: No such domain" % domainname, file=sys.stderr)
            return None
        except Exception as e:
            print("%s: unexpected Exception on" % domainname, file=sys.stderr)
            print(e)
            print("Retrying...")
    print("Giving up on %s after %d timeouts" % (domainname, RETRIES), file=sys.stderr)
    return None


if __name__ == "__main__":
    # Check for domain names provided
    if len(sys.argv) < 2:
        print("Usage: {} <domain1> <domain2> ... <domainN>".format(sys.argv[0]))
        sys.exit(1)

    domainlist = []
    for name in sys.argv[1:]:
        domain = get_domain(name)
        if not domain:
            print("Can't get info for %s" % name)
            continue
        if not domain.expiration_date:
            print("WARNING: Can't get expiration date for %s" % name)
            continue
        elif hasattr(domain.expiration_date, "__len__"):
            expdate = min(domain.expiration_date)
        else:
            expdate = domain.expiration_date

        domainlist.append((name, expdate.date(), domain.registrar))

    today = datetime.date.today()
    month_index = today.month - 1 + 2
    year = today.year + month_index // 12
    month = month_index % 12 + 1
    two_months_from_now = datetime.date(
        year, month, min(today.day, calendar.monthrange(year, month)[1])
    )
    print(format % ("Domain", "Expires", "", "Registrar"))
    for d in domainlist:
        # Determine color based on expiration status
        if d[1] < datetime.date.today():
            exp_date_display = RED + d[1].strftime("  %Y-%m-%d") + RESET  # Red for expired domains
        elif d[1] < two_months_from_now:
            exp_date_display = (
                YELLOW + d[1].strftime("  %Y-%m-%d") + RESET
            )  # Yellow warning for expiring in less than two months
        else:
            exp_date_display = d[1].strftime("  %Y-%m-%d")  # Normal display for valid dates

        print(format % (d[0], exp_date_display, "", d[2]))
