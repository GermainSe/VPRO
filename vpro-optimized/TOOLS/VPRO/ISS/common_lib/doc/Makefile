

.PHONY: doc clean

doc:
	@echo "generating HTML doc ..."
	@doxygen Doxyfile
	@cp example.html html/.
	@echo "generated HTML doc"
	ln -s html/namespaceVPRO_1_1DIM3.html dim3.html

clean:
	@echo "cleaning html and latex folder"
	@rm -rf html latex
