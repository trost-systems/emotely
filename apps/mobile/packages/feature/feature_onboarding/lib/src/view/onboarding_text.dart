// The words of onboarding, in the companion's voice: it speaks as "I"
// (CONTEXT.md, Companion). One place, so a copy change is one diff.

const welcomeTitle = 'Welcome to emotely';
const welcomeBody =
    'A few guided minutes a day to notice how you feel – and why.';
const getStartedLabel = 'Get started';
const haveAccountLabel = 'I have an account';

const valueTitle = 'Here is what a few minutes gets you';

/// The three promises, title and line, in the order they are shown.
const promises = [
  (
    title: 'Guided, one question at a time',
    body:
        'Pick a set of questions. emotely asks, listens and follows up – '
        'no blank page.',
  ),
  (
    title: 'Answer your way',
    body:
        'Words, emojis, colours or a quick rating – whatever fits the moment.',
  ),
  (
    title: 'A journal that writes itself',
    body:
        'Every session ends in an entry you can reread – and spot what keeps '
        'coming back.',
  ),
];

const continueLabel = 'Continue';
const backLabel = 'Back';

const nameTitle = 'Before we start – what should I call you?';
const nameBody = 'A first name or a nickname is perfect.';
const nameLabel = 'Your name';
const nameHint = 'First name or nickname';
const nameUse =
    'Only used to greet you – in the app and in your sessions. '
    'Change it any time in your profile.';
const nameTooLong = 'That is a little long for me – 40 characters at most.';
const nameInvisibleCharacter =
    'Please leave out tabs and other invisible characters.';
const skipLabel = 'Skip for now';

String helloTitle(String name) => 'Nice to meet you, $name.';
const helloBody =
    'Your first reflection takes about five minutes. I ask, you answer – '
    'in words, emojis or colours.';

const skippedTitle = 'Fine, stay mysterious.';
String skippedBody(String placeholder) =>
    'I’ll call you $placeholder for now. When you’re ready to tell me your '
    'real name, it’s in your profile.';
const tellYouLabel = 'Actually, I’ll tell you';

const startReflectionLabel = 'Start my first reflection';

const saveFailedMessage =
    'I could not save your name just now. Check your connection and try '
    'again.';
const retryLabel = 'Try again';
