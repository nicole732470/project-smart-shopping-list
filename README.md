# PriceTracker (Smart Shopping List)

## Team

Nicole Li, Andrew Xue, Amie Masih, Rahib Taher

## MVP

A web app where signed-in users save products they are watching, record prices seen at different stores, and review them from a simple dashboard. The baseline vision is to paste a product link, set a target price, and get notified when the price meets that condition (notifications are a stretch goal beyond the current milestone).

## Communication

- Weekly meetings on Saturday afternoons, with extra syncs when the app or deadlines need them.
- Decisions are coordinated through those meetings and ongoing chat; the team aims for consensus.
- If consensus is not reached in a reasonable time, decisions are resolved by majority vote.
- Decisions are documented with rationale. Small decisions can be async; blocking or complex issues are raised in meetings or escalated early.
- Choices prioritize simplicity and alignment with the MVP so progress stays steady.

## Links

- **OO design (Miro):** https://miro.com/app/board/uXjVGjU99U8=/
- **Scheduling (When2meet):** https://www.when2meet.com/?36156767-PyTqS
- **Heroku deployment:** https://smart-shoppinglist-6ae31171e85c.herokuapp.com/

## Ideas captured from early planning

- Save product links to the database with a user id.
- Save the date an item was added.
- Optionally save an image per item.
- After login, show a grid of saved items with cards; mark items as resolved.
- Set a “buy at” price and notify when price drops to that margin.
- Start by storing the price you saw manually (scraping across stores is uncertain).
