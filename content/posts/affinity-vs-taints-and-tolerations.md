---
title: "affinity-vs-taints-and-tolerations"
publish: false
type: garden
tags: []
created: 2025-12-30
---

#cka #course #k8s #kubernetes #cncf #publish

# affinity-vs-taints-and-tolerations

You may need to do a combination of both: taints + tolerations & node affinity.

A tainted node with a matching toleration on a POD allows that POD to join the tainted node.
This does not mean that the POD could not be assigned to a different node, only that it is *able* to join that
tainted node.

This is where Node Affinity comes into play. It technically (with a taints & tolerations), forces that POD
to join the correct Node.

If you only have Node affinity, it won't keep undesired PODs from joining your Node. That is why you need to apply
taints, and tolerations to the desired PODs.

---

*Updated via automated workflow*

202503281250
