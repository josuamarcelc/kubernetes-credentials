LINTERS=\
    gofmt \
    golint \
    gosimple \
    vet \
    misspell \
    ineffassign \
    deadcode

ci: $(LINTERS) test

.PHONY: ci

#################################################
# Bootstrapping for base golang package deps
#################################################

BOOTSTRAP=\
    github.com/golang/dep/cmd/dep \
    github.com/alecthomas/gometalinter \
	k8s.io/kubernetes/hack/boilerplate \
	github.com/kubernetes/code-generator/cmd/deepcopy-gen

$(BOOTSTRAP):
	go get -u $@
bootstrap: $(BOOTSTRAP)
	gometalinter --install

vendor: Gopkg.lock
	dep ensure

install: vendor
	go run *.go -kubeconfig=$(HOME)/.kube/config

.PHONY: bootstrap $(BOOTSTRAP)

#################################################
# Building
#################################################

generated: primitives/zz_generated.go
	deepcopy-gen -v=5 -i github.com/manifoldco/kubernetes-credentials/primitives -O zz_generated

bin/controller: vendor generated
	CGO_ENABLED=0 GOOS=linux go build -a -o bin/controller ./controller

docker: bin/controller
	docker build -t manifoldco/kubernetes-credentials-controller .

.PHONY: generated

#################################################
# Test and linting
#################################################

test: vendor
	@CGO_ENABLED=0 go test -v ./...

METALINT=gometalinter --tests --disable-all --vendor --deadline=5m -s data \
     ./... --enable

$(LINTERS): vendor
	$(METALINT) $@

.PHONY: $(LINTERS) test
