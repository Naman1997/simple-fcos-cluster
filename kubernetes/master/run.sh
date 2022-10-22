#!/bin/sh
nixops create -d kubernetes configuration.nix > out
nixops deploy -d `cat out` --force-reboot
