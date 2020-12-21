$fn = 60;

LENGTH = 180;
WIDTH = 150;
THICKNESS = 5;

OBLONG_DIAMETER = 5.5;
OBLONG_LENGTH = 15;

TUBE_DIAMETER = 26.9;

BOLT_DIAMETER = 4.5;
BOLT_HEAD_DIAMETER = 9;
NUT_DIAMETER = 8.25;
NUT_HEIGHT = 6;

module roundedBox(w,h,d,f){
	difference(){
        cube(size=[w, h, d], center=true);
		translate([-w/2,h/2,0]) cube(w/(f/2),true);
		translate([w/2,h/2,0]) cube(w/(f/2),true);
		translate([-w/2,-h/2,0]) cube(w/(f/2),true);
		translate([w/2,-h/2,0]) cube(w/(f/2),true);
	}
	translate([-w/2+w/f,h/2-w/f,-d/2]) cylinder(d,w/f, w/f);
	translate([w/2-w/f,h/2-w/f,-d/2]) cylinder(d,w/f, w/f);
	translate([-w/2+w/f,-h/2+w/f,-d/2]) cylinder(d,w/f, w/f);
	translate([w/2-w/f,-h/2+w/f,-d/2]) cylinder(d,w/f, w/f);
}

module oblong(diameter, length, thickness) {
    translate([-length / 2, 0, 0]) {
        hull() {
            cylinder(d=diameter, h=thickness);
            translate([length, 0, 0]) {
                cylinder(d=diameter, h=thickness);
            }
        }
    }
}

module nut(diameter, height) {
    cylinder(d=diameter, h=height, $fn=6);
    //%cylinder(d=7.8, h=height, $fn=40);
}

module tube_holder(diameter, length) {
    difference() {
        hull() {
            cube(size=[diameter * 3, length, 1], center=true);
            translate([0, length / 2, diameter]) {
                rotate([90, 0, 0]) {
                    cylinder(d=diameter * 2, h=length);
                }
            }
        }

        translate([0, length, diameter]) {
            rotate([90, 0, 0]) {
                cylinder(d=diameter, h=length * 2);
            }
        }

        translate([0, 0, diameter * 2 - 3]) {
            cylinder(d=BOLT_HEAD_DIAMETER, h=diameter);
        }
        cylinder(d=BOLT_DIAMETER, h=diameter * 2);
    }
}

module main() {
    item_position = LENGTH / 2 - 35;

    difference() {
        union() {
            difference() {
                roundedBox(LENGTH, WIDTH, THICKNESS, 10);

                for (position = [
                    [item_position, WIDTH / 2 - 15, 0],
                    [-item_position, WIDTH / 2 - 15, 0],
                    [item_position, -(WIDTH / 2 - 15), 0],
                    [-item_position, -(WIDTH / 2 - 15), 0],
                ]) {
                    translate(position) {
                        translate([0, 0, -THICKNESS]) {
                            oblong(OBLONG_DIAMETER, OBLONG_LENGTH, THICKNESS * 2);
                        }
                    }
                }

                roundedBox(LENGTH / 3.5, WIDTH / 1.8, THICKNESS * 2, 10);
            }

            for (x=[item_position, -item_position]) {
                translate([x, 0, 0]) {
                    rotate([0, 0, 90]) {
                        tube_holder(TUBE_DIAMETER, 30);
                    }
                }
            }
        }

        for (x=[item_position, -item_position]) {
            translate([x, 0, -THICKNESS / 2 - .1]) {
                nut(NUT_DIAMETER, NUT_HEIGHT);
            }
        }
    }
}

// Test
intersection() { translate([0, 0, 27]) cube(size=[43, 50, 35], center=true); tube_holder(TUBE_DIAMETER, 30); }
tube_holder(TUBE_DIAMETER, 30);
oblong(OBLONG_DIAMETER, OBLONG_LENGTH, THICKNESS);
difference() { cylinder(d=15, h=10); translate([0, 0, -.1]) nut(NUT_DIAMETER, NUT_HEIGHT); cylinder(d=BOLT_DIAMETER, h=100); }

!main();

