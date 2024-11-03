#!/usr/bin/env python

# Display renewal dates for a list of domains given on the command line.
# Copyright 2021 by Akkana Peck; share and enjoy under the GPLv3 or later.

from __future__ import print_function
import sys
import socket
import datetime
from dateutil.relativedelta import relativedelta

try:
    import whois
except ImportError:
    print("""Couldn't import whois. Try:
    apt install python3-whois
or
    pip3 install python-whois
(Those are two different packages, but both are supported.
The one from pip tends to time out; the one from apt is more reliable.)
""")
    sys.exit(1)

# ANSI color codes
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"

# Adjusted format to move date column one space to the right
format="%25s %11s %3s %s"

def get_domain(domainname):
    if hasattr(whois, 'query'):
        return get_domain_apt_python3whois(domainname)
    return get_domain_pip_pythonwhois(domainname)

RETRIES = 6

def get_domain_apt_python3whois(domainname):
    for i in range(RETRIES):
        try:
            return whois.query(domainname)
        except:
            print("Problem on", domainname, "retrying ...", file=sys.stderr)
    print("Giving up on %s after %d timeouts" % (domainname, RETRIES), file=sys.stderr)
    return None

def get_domain_pip_pythonwhois(domainname):
    for i in range(RETRIES):
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

if __name__ == '__main__':
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

    two_months_from_now = datetime.datetime.today() + relativedelta(months=2)
    two_months_from_now = two_months_from_now.date()
    print(format % ("Domain", "Expires", "", "Registrar"))
    for d in domainlist:
        # Determine color based on expiration status
        if d[1] < datetime.date.today():
            exp_date_display = RED + d[1].strftime('  %Y-%m-%d') + RESET  # Red for expired domains
        elif d[1] < two_months_from_now:
            exp_date_display = YELLOW + d[1].strftime('  %Y-%m-%d') + RESET  # Yellow warning for expiring in less than two months
        else:
            exp_date_display = d[1].strftime('  %Y-%m-%d')  # Normal display for valid dates

        print(format % (d[0], exp_date_display,  "", d[2]))
