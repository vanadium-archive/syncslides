# Overview

Syncslides uses Syncbase for data storage and communication between users'
devices.

# Detailed Design

## Types

All types are prefixed with 'V' because the Java version needs to have
interfaces with similar names.

```
// VDeck is the metadata for a set of slides.
type VDeck struct {
  Title string
  Thumbnail []byte
}

// VSlide contains the image content for the slide.
type VSlide struct {
  // A low-res version of the image stored as JPG.
  Thumbnail []byte
  // A high-res version of the image stored as JPG.
  Fullsize Blobref  // NOTE: Not currently implemented.
}

// VNote contains private-to-the-user notes for a specific slide.
type VNote struct {
  Text string
}

// VPresentation represents a live display of a VDeck.
type VPresentation struct {
  // Owner is responsible for advertising the presentation and has full
  // control of it.
  Owner VPerson
  // Driver represents who has control of the presentation.  Usually, it is
  // the presenter, but the presenter can give control to an audience member
  // by changing this field.
  Driver VPerson
}

// VPerson represents either an audience member or the presenter.
type VPerson struct {
  Blessing string
  // The person's full name.
  Name string
}

// VCurrentSlide contains state for the live presentation.  It is separate
// from the VPresentation so that the presenter can temporarily delegate
// control of the VCurrentSlide without giving up control of the entire
// presentation.
type VCurrentSlide struct {
  // The number of the slide that the presenter is talking about.
  SlideNum int32
  // In the future, we could add markup/doodles here.  That markup would be
  // transient if stored here.  Maybe better to put it in a separate row...
}

// VQuestion represents a member of the audience asking a question of the
// presenter. TODO(kash): Add support for the user to type in their question.
// Right now, they need to ask their question verbally.
type VQuestion struct {
  // The person who asked the question.
  Questioner VPerson
  // Time when the question was asked in milliseconds since the epoch.
  Time int64
  // Track whether this question has been answered.
  Answered bool
}

// VSession represents UI state that most apps would consider to be ephemeral.
// By storing it in Syncbase, we can resume a session on another device.
// It also simplifies the Android implementation because we don't have to store
// all of this state in a Bundle for each Activity/Fragment.
type VSession struct {
  DeckId string
  PresentationId string
  // When the user is not driving the presentation, he can go forward/back in
  // the deck on his own.  A value of -1 means the user is following the
  // driver of the presentation.
  LocalSlide int32
  // The time that this session was last used in milliseconds since the epoch.
  // This field allows us to find the most recently used session and prompt
  // the user to resume it.
  LastTouched int64
}
```

## Table `Decks`

A deck is a set of slides plus metadata.  It can be used in multiple
presentations.  It is owned by the presenter, and the audience has read-only
access.

The deck is immutable because we use the simple scheme of ordering slides by
their key (see example below).  The other tables refer to the slides by these
hardcoded names, so those references would break if we allowed deck mutations.

```
<deckId>            --> VDeck
<deckId>/slides/1   --> VSlide
<deckId>/slides/2   --> VSlide
<deckId>/slides/3   --> VSlide
...
```

## Table `Notes`

Notes are private to a user.  They are sparse in that if a user does not have
any notes for a slide, the corresponding row is not present.

The `lastViewed` row contains the timestamp that the user last viewed the
presentation in milliseconds since the epoch. TODO(kash): Can we replace this
with vdl.Time?  Does it work in Java?

```
<deckId>/LastViewed  --> int64
<deckId>/slides/1    --> VNote
<deckId>/slides/5    --> VNote
```

## Table `Presentations`

A presentation represents a presenter displaying a deck to an audience.
```
<deckId>/<presentationId>                         --> VPresentation
<deckId>/<presentationId>/CurrentSlide            --> VCurrentSlide
<deckId>/<presentationId>/questions/<questionId>  --> VQuestion
```

## Table `UI`

This table contains state that is specific to the UI.  It allows the user to
resume on another device.

```
<sessionId>  --> VSession
```

## Syncgroups

There are multiple syncgroups as part of a live presentation.
* The presentation syncgroup contains:
  * Table: Decks, Prefix: `<deckId>`
    * ACL: Presenter: RWA, Audience: R
  * Table: Presentation, Prefix: `<deckId>/<presentationId>`
    * ACL: Presenter: RWA, Audience: R
* The notes syncgroup contains:
  * Table: Notes, Prefix: `<deckId>`
    * ACL: Person who wrote the notes: RWA
* The UI syncgroup contains:
  * Table: UI, Prefix: ``  (Everything)
    * ACL: The person who wrote the value: RWA

## Delegation

We want to be able to temporarily delegate control of the presentation to an
audience member. The presenter will do this by writing the audience member's
name to the VPresentation struct in the Presentations table.  The presenter
will also set the ACL on the VCurrentSlide so that audience member can write
it.  When the presenter wants control again, she will reverse these steps.

## Questions

When a user wants to ask a question, their device needs to write a VQuestion
struct into the Presentations table.  The
`<deckId>/<presentationId>/questions` prefix will be writable to everyone.
When the questioner adds a question, they will also add an ACL just for that
row.  The ACL will give write access to that user and to the presenter.
