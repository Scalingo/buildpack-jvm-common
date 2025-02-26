#!/bin/bash

if [ ! -f /app/Procfile ] && [ "${CONTAINER}" = "web-1" ]; then
	echo "Create a Procfile to customize the command used to run this process: https://doc.scalingo.com/platform/app/procfile"
fi
