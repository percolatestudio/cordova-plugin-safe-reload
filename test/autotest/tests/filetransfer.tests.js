
var _it = it;
it = function (text, funk) {
    if (text.indexOf("filetransfer.spec.7") == 0) {
        return _it(text, funk);
    }
    else {
        console.log("Skipping Test : " + text);
    }
}


describe('SafeReload', function() {
    
    it("safereload.spec.1 is alive", function() {
        var sr = new SafeReload();
        expect(sr).toBeDefined();
    });

});
