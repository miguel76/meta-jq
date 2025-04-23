def publishContent: .;
def publishPage: {result:.};

.classes.Philosopher | [3,5,7] | {
    title: "A list of ancient philosophers",
    contentURIs: 
        [
            .hasInstance[] | select(.birthDate < "500-01-01T00:00:00Z") |
            {
                id: .id,
                name: "\(.firstName) \(.familyName)",
                students: [
                    .hasStudent[] | .id
                ],
                studentsOfStudents: [
                    .hasStudent[] | .hasStudent[] | .id
                ]
            } | publishContent | @url "https://example.org/\(.reference)"
        ]
} | publishPage | .result
