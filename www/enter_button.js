$(document).keyup(function(event) {
    // if (($("#grade").is(":focus") && (event.key == "Enter")) || $("#comment").is(":focus") && (event.key == "Enter")) {
    if (($("#grade").is(":focus") && (event.key == "Enter")) ) {
        $("#goButton").click();
    }
});
