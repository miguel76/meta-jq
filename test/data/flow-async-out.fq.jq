module {   
    descr: "aloha"
};

import ciccio as cicius {   
    info: "cicciomede"
};

import bimbo as $birimbo {   
    furbo: {  
        ah: [4],
        meno: 1,
        ops: null,
        piu: 1
    },
    main: "bubolo",
    quattro: false,
    rumba: 4
};

include included {   
    isIncluded: true
};

def publishContent:   
    .;

def publishPage:   
    {  
        result: [. , .[] , .],
        ciccio: [empty]
    };

.classes | .Philosopher | .[35] | .[35:] | 4 + 5 * 6 + 5 | [4 , 5 + 6] | .a |= . + 42 | true | false | .who | .[3 , 5 , 7] | .pippo | .[] | .rido // .piango // .serie | .[3] | .[] as {$a, $b, c: {$d, $e}}, {$a, $b, c: [{$d, $e}]}, {$a, $b, c: [[{$d, $e}]]} | {   
    $a,
    $b,
    $d,
    $e
} | .ciccio | length as $pasticcio | {   
    title: "A list of ancient philosophers",
    contentURIs: [.hasInstance | .[] | select(.birthDate < "500-01-01T00:00:00Z") | {  
        id: .id,
        name: "\(.firstName) \(.familyName)",
        duo: "pippo" | @base64,
        trio: @uri "pluto",
        students: [.hasStudent | .[] | .id],
        studentsOfStudents: [.hasStudent | .[] | .hasStudent | .[] | .id]
    } | publishContent | @url "https://example.org/\(.reference)"]
} | publishPage | .result | -6
