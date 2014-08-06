#!/usr/bin/groovy
import groovy.json.*


if (args.length < 1) {
	println "Need instance id to find"
	System.exit(1)
}
def soughtId = args[0]
def data = new JsonSlurper().parse(new InputStreamReader(System.in))
def found

data.Reservations.each { reservation ->
	def foundInstance = reservation.Instances.find { instance ->
		instance.InstanceId == soughtId
	}
	if (foundInstance) {
		found = foundInstance.Placement.AvailabilityZone
	}
}

println found
