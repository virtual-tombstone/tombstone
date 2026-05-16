#!/bin/v run

import build
import make

mut context := build.context()
make.context_help(mut context)
make.context_git(mut context)
make.context_v(mut context)
context.run()
