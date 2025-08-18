#!/usr/bin/python3
import socket
from socket import gethostbyname, gethostbyaddr
import sys
import requests
import json
import colors
import subprocess
import re

def get_ip():
    try:
        while True:
            t_host = input("Enter the name of the host: ")
            if t_host.isdigit():
                print(colors.green("Please provide a valid FQDN domain name!"))
            elif t_host.strip() == "":
                print(colors.bold(colors.red("Invalid input!")))
            else:
                hostname_ip = gethostbyname(t_host)
                print(f"IP address of the domain: {colors.bold(colors.green(hostname_ip))}")
                break
    except socket.gaierror:
        print(colors.bold(colors.red("Invalid domain name!")))
    except KeyboardInterrupt:
        print(colors.bold("\nProgram Aborted"))
        sys.exit()

def is_valid_ip(ip):
    # Regular expression for validating an IP address
    pattern = re.compile(r"^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$")
    return pattern.match(ip) is not None

def get_host():
    try:
        while True:
            t_ip = input("Enter the IP of the host: ")
            if t_ip.islower() or t_ip.isupper():
                print(colors.bold(colors.green("Please provide a numerical value!")))
            elif t_ip.strip() == "":
                print(colors.bold(colors.red("Invalid input!")))
            else:
                ip_hostname = gethostbyaddr(t_ip)
                print("Hostname: {}".format(ip_hostname).replace(", []", ''))
                break
    except socket.herror:
        print(colors.bold("Unknown host!"))
    except socket.gaierror:
        print(colors.bold(colors.red("DNS lookup failed!")))
    except KeyboardInterrupt:
        print(colors.bold("\nProgram Aborted"))
        sys.exit()

def get_ip_location():
    try:
        while True:
            ip_addr = input("Enter an IP address: ")
            if ip_addr.strip() == "":
                print(colors.bold(colors.red("Invalid input!")))
            elif ip_addr.islower() or ip_addr.isupper():
                print(colors.bold(colors.green("Please provide a numerical value!")))
            else:
                request = requests.get(f"https://ipinfo.io/{ip_addr}/json")
                if request.status_code != 200:
                    print(colors.bold(colors.red("Connection error!")))
                    sys.exit()
                else:
                    response = request.json()
                    ip_info = (
                        f"Country   : {response['country']}",
                        f"Location  : {response['region']}",
                        f"City      : {response['city']}"
                    )
                    print()
                    for x in ip_info:
                        print(x)
                    break
    except KeyboardInterrupt:
        print(colors.bold("\nProgram Aborted"))
        sys.exit()

def IPTool():
    while True:
        print()
        print(colors.bold(colors.blue("=== IP Address Tool ===")))
        print("""
        1) Get IP address from a hostname
        2) Get the hostname of an IP address
        3) Get IP address geolocation
        4) Exit
        """)
        try:
            choice = input("Choose an option: ")
            if choice == "1":
                get_ip()
            elif choice == "2":
                get_host()
            elif choice == "3":
                get_ip_location()
            elif choice == "4":
                print(colors.bold(colors.red("Program exited.")))
                sys.exit()
            else:
                print(colors.bold(colors.red("Invalid entry!")))
        except KeyboardInterrupt:
            print(colors.bold("\nProgram Aborted"))
            sys.exit()

IPTool()
