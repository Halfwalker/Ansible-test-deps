#!/bin/bash

ANSIBLE_STDOUT_CALLBACK=minimal ansible-playbook -i hosts test.yml $@ -- | egrep -v "{|}"
