#!/bin/bash
set -e

export IS_ENTRY_POINT=1
exec init-postgres.sh "$@"
