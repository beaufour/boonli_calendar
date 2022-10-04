#!/bin/bash
# Runs the Cloud Functions locally

export KEY_NAME="boonli-menu-key"
export KEY_RING_LOCATION="global"
export KEY_RING_NAME="boonli-menu-keyring"
export PROJECT_NAME="boonli-menu"

func_name="calendar"
port_number=8080
if [[ "$1" == "encrypt" ]]; then
    func_name="encrypt"
    port_number=8081
fi

functions-framework --target ${func_name} --port ${port_number} --debug
