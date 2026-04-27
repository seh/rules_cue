@extern(embed)
package text

#LetterCountsByWord: [string]: uint

counts: #LetterCountsByWord @embed(file=letter-counts.json)
