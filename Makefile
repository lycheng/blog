.PHONY: clean run deploy

run:
	hexo server

clean:
	hexo clean

deploy: clean
	hexo deploy
