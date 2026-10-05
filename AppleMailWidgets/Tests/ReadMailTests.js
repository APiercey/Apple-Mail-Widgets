// Run with: node AppleMailWidgets/Tests/ReadMailTests.js
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../Sources/App/ReadMail.js'), 'utf8');

function read(rows, { changeIDs = false, mismatchDates = false, running = true } = {}) {
    let idReads = 0;
    let headerReads = 0;
    const messages = {
        id: () => { idReads++; return rows.map(m => m.id + (changeIDs && idReads > 1 ? 1000 : 0)); },
        dateReceived: () => rows.slice(mismatchDates ? 1 : 0).map(m => new Date(m.time)),
        readStatus: () => rows.map(m => m.read),
        deletedStatus: () => rows.map(m => m.deleted),
        junkMailStatus: () => rows.map(m => m.junk),
        whose: () => { throw Error('Slow mailbox-wide predicates must not be used'); },
        byId: id => {
            headerReads++;
            const row = rows.find(m => m.id === id);
            return { sender: () => 'Example', subject: () => 'Fixture', messageId: () => id+'@example.com', readStatus: () => row.read };
        }
    };
    const account = { id: () => 'work', enabled: () => true, name: () => 'Work', emailAddresses: () => ['work@example.com'] };
    const box = { account: { id: () => 'work' }, messages, unreadCount: () => 40 };
    const context = vm.createContext({ Application: () => ({ running: () => running, accounts: () => [account], inbox: { mailboxes: () => [box] } }) });
    vm.runInContext(source, context);
    const result = JSON.parse(context.run(['work']));
    return { result, headerReads };
}
const rows = Array.from({length:30}, (_,i) => ({id:i+1,time:i*1000,read:i%3===0,deleted:false,junk:false}));
rows[29].deleted = true;
rows[28].junk = true;
const expected = rows.filter(m => !m.deleted && !m.junk).reverse();
const {result,headerReads} = read(rows);
const inbox = result.inboxes[0];
assert.deepEqual(inbox.recentMessages.map(m => m.id), expected.slice(0,10).map(m => m.id));
assert.deepEqual(inbox.unreadMessages.map(m => m.id), expected.filter(m => !m.read).slice(0,10).map(m => m.id));
assert.equal(inbox.unreadCount,40);
assert.ok([...inbox.recentMessages,...inbox.unreadMessages].every(m => m.inboxID==='work'));
assert.equal(headerReads,new Set([...inbox.recentMessages,...inbox.unreadMessages].map(m=>m.id)).size);
assert.throws(()=>read(rows,{changeIDs:true}),/Inbox changed/);
assert.throws(()=>read(rows,{mismatchDates:true}),/Inbox changed/);
assert.equal(read([]).result.inboxes[0].recentMessages.length,0);
assert.equal(read(rows,{running:false}).result.status,'mailClosed');
assert.equal(read(rows.map(m=>({...m,read:true}))).result.inboxes[0].unreadMessages.length,0);
console.log('PASS: bulk columns, newest ten, unread/all, excluded messages, account IDs, header reuse, concurrent mailbox changes, empty/closed Mail');
