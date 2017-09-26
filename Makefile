.PHONY:	publish publish-beta default all docker-build clean

default: all

all: lvmify.iso

lvmify.iso: docker-build
	docker run --rm nanobox/lvmify > lvmify.iso

docker-build:
	docker build -t nanobox/lvmify -f Dockerfile . 

clean:
	if [ -f lvmify.iso ]; then rm lvmify.iso; fi

publish:
	aws s3 cp \
		lvmify.iso \
		s3://tools.nanobox.io/lvmify/v1/lvmify.iso \
		--grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers \
		--region us-east-1

publish-beta:
	aws s3 cp \
		lvmify.iso \
		s3://tools.nanobox.io/lvmify/beta/lvmify.iso \
		--grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers \
		--region us-east-1