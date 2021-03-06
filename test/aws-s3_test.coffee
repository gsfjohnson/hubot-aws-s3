chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

describe 'aws-s3', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()

    require('../src/aws-s3')(@robot)

  it 'registers a respond listener for calculating', ->
    expect(@robot.respond).to.have.been.calledOnce
