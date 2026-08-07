-- Smoke spec: verifies the isolated test environment loads plenary and can
-- resolve pi.cr modules from the config rtp.
describe("pi.cr test infra", function()
  it("loads plenary", function()
    assert.is_function(require("plenary").test_harness.test_directory)
  end)

  it("resolves existing pi.cr modules on the rtp", function()
    assert.truthy(package.searchpath("pi.cr.comments", package.path))
  end)
end)
