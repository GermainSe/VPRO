

.PHONY: doc clean

doc:
	@echo "generating HTML doc ..."
	@cd .. && doxygen
	@cp example.html html/.
	@echo "generated HTML doc"

clean:
	@echo "cleaning html and latex folder"
	@rm -rf html latex
