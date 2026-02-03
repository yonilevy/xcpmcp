PREFIX ?= $(HOME)/.local/bin
BINARY = .build/release/xcpmcp

.PHONY: build install uninstall clean

build:
	swift build -c release

install: build
	mkdir -p $(PREFIX)
	cp $(BINARY) $(PREFIX)/xcpmcp
	@echo ""; \
	case ":$$PATH:" in \
		*":$(PREFIX):"*) ;; \
		*) echo "WARNING: $(PREFIX) is not in your PATH."; \
		   echo "Add this to your shell profile:"; \
		   echo ""; \
		   echo "  export PATH=\"$(PREFIX):\$$PATH\""; \
		   echo "" ;; \
	esac
	@printf "Register xcpmcp as a Claude Code MCP server? [y/N] "; \
	read ans; \
	case "$$ans" in \
		[yY]*) claude mcp add --transport stdio --scope user xcpmcp -- $(PREFIX)/xcpmcp ;; \
		*) echo "Skipped. You can register it later with:"; \
		   echo ""; \
		   echo "  claude mcp add --transport stdio --scope user xcpmcp -- $(PREFIX)/xcpmcp"; \
		   echo "" ;; \
	esac

uninstall:
	claude mcp remove xcpmcp || true
	rm -f $(PREFIX)/xcpmcp

clean:
	swift package clean
